# =====================================================================
# CERTIFICATION SCENARIO 189: POINT-TO-POINT SECURITY MONITORING
# COMPONENT: EVENTBRIDGE PIPES ROUTING DATA EVENTS TO ISOLATION LAMBDAS
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

# 1. Reference Your Central Anomaly Communication Channels (From Phase 4 Core Network)
data "aws_sns_topic" "security_ops_alerts" {
  name = "enterprise-critical-root-access-alerts"
}

# 2. Deploy the Serverless Threat Isolation Worker Function (AWS Lambda)
resource "aws_lambda_function" "identity_network_isolator" {
  function_name = "Enterprise-Core-Network-IdentityIsolator"
  role          = aws_iam_role.pipes_security_execution_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "mock-network-isolator.zip"
  timeout       = 30

  # Buildspec inline note: Real-time script that extracts the offending principal,
  # finds their active network ingress targets, and severs security group mapping arrays.
}

# 3. Create the Secure IAM Execution Role for the Point-to-Point Pipe Engine
resource "aws_iam_role" "pipes_security_execution_role" {
  name = "DataCenter-EventBridge-Pipes-SecurityRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com", Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege tokens enabling the pipe engine to read streams and invoke lambdas
resource "aws_iam_role_policy" "pipes_security_least_privilege" {
  name = "EventBridge-Pipes-Security-Transit-Access"
  role = aws_iam_role.pipes_security_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.identity_network_isolator.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DescribeSecurityGroups"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}

# 4. Architect the Hardened Point-to-Point Amazon EventBridge Pipe Security Corridor
resource "aws_pipes_pipe" "security_incident_pipe" {
  name     = "enterprise-data-events-to-network-isolator-pipe"
  role_arn = aws_iam_role.pipes_security_execution_role.arn
  
  # SOURCE DIRECTION: Ingest logs automatically from your centralized CloudTrail stream bus
  source = "arn:aws:kinesis:us-east-1:123456789012:stream/enterprise-global-cloudtrail-bus"

  # SOURCE OPTIMIZATION PARAMETERS: Tightly configures ingestion batching windows
  source_parameters {
    kinesis_stream_parameters {
      batch_size                         = 5  # Small batch size ensures near-instantaneous triage
      maximum_batching_window_in_seconds = 1  # Process payloads immediately within 1 second
      starting_position                  = "LATEST"
    }

    # INTEGRATED SOURCE FILTERING FILTER
    # Screens and intercepts only unauthorized data plane modification attempts
    filter_criteria {
      filter {
        pattern = jsonencode({
          detail = {
            eventName = ["PutBucketPolicy", "ModifyDBInstance"],
            errorCode = ["AccessDenied", "UnauthorizedOperation"]
          }
        })
      }
    }
  }

  # TARGET DIRECTION: Streams clean payloads directly down to the serverless Lambda worker
  target = aws_lambda_function.identity_network_isolator.arn

  tags = {
    Layer      = "Point-To-Point-Security-Streaming"
    SavedAsset = "True"
  }

  depends_on = [aws_iam_role_policy.pipes_security_least_privilege]
}
