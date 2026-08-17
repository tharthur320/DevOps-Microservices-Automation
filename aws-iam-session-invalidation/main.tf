# =====================================================================
# CERTIFICATION SCENARIO 115: SELF-HEALING IDENTITY ACCESS CONTROL
# COMPONENT: EVENTBRIDGE PIPES & LAMBDA INVALIDATING COMPROMISED SESSIONS
# =====================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# 1. Reference Your Central Anomaly Notification Topic (From Phase 4 Core Network)
data "aws_sns_topic" "security_ops_alerts" {
  name = "enterprise-critical-root-access-alerts"
}

# 2. Architect the CloudWatch Event Rule Catching Dangerous S3 Control Plane Drift
resource "aws_cloudwatch_event_rule" "bucket_tamper_monitor" {
  name        = "capture-s3-bucket-sabotage-attempts"
  description = "Intercepts unauthorized data plane and policy modifications at the infrastructure edge"

  event_pattern = jsonencode({
    "source": ["aws.s3"],
    "detail-type": ["AWS API Call via CloudTrail"],
    "detail": {
      "eventSource": ["://amazonaws.com"],
      "eventName": [
        "PutBucketPolicy",
        "DeleteBucketPolicy",
        "PutBucketPublicAccessBlock"
      ]
    }
  })
}

# 3. Create the Secure IAM Execution Role for the EventBridge Pipes Transit Hub
resource "aws_iam_role" "pipes_session_invalidator_role" {
  name = "DataCenter-EventBridgePipes-SessionInvalidator-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# 4. Deploy the Serverless Identity Locksmith Worker Function (AWS Lambda)
resource "aws_lambda_function" "session_killer" {
  function_name = "Enterprise-Core-IAM-SessionKiller"
  role          = aws_iam_role.pipes_session_invalidator_role.arn # Reuses verified execution container roles
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "mock-session-killer.zip"
  timeout       = 30

  # Buildspec inline note: Real-time script that ingests the specific AssumedRoleSessionName,
  # generates an explicit Deny policy, and binds it straight into the active AWS STS token.
}

# Bind explicit least-privilege tokens enabling the pipe infrastructure to forward data blocks
resource "aws_iam_role_policy" "pipe_execution_privileges" {
  name = "EventBridge-Pipes-SessionTransit-Access"
  role = aws_iam_role.pipes_session_invalidator_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.session_killer.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = data.aws_sns_topic.security_ops_alerts.arn
      }
    ]
  })
}

# 5. Connect the Systems Monitor Directly to the Lambda Target via EventBridge Pipes
# (This native bridge bypasses heavy pipeline architectural middleman code blocks)
resource "aws_pipes_pipe" "security_invalidation_pipe" {
  name     = "enterprise-threat-to-session-invalidator-pipe"
  role_arn = aws_iam_role.pipes_session_invalidator_role.arn
  source   = aws_cloudwatch_event_rule.bucket_tamper_monitor.arn
  target   = aws_lambda_function.session_killer.arn

  source_parameters {
    filter_criteria {
      filter {
        pattern = jsonencode({
          "detail": {
            "userIdentity": {
              "type": ["AssumedRole"] # Focuses exclusively on transient assumed role sessions
            }
          }
        })
      }
    }
  }

  tags = {
    Layer      = "Self-Healing-Identity-Perimeter"
    SavedAsset = "True"
  }

  depends_on = [aws_iam_role_policy.pipe_execution_privileges]
}
