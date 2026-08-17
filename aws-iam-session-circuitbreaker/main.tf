# =====================================================================
# CERTIFICATION SCENARIO 142: AUTONOMOUS IDENTITY SESSION ISOLATION
# COMPONENT: EVENTBRIDGE & LAMBDA TRIGGERING TARGETED STS INVALIDATIONS
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

# 1. Reference Your Central Anomaly Notification Channel (From Phase 4 Core Network)
data "aws_sns_topic" "soc_alert_node" {
  name = "enterprise-critical-root-access-alerts"
}

# 2. Architect the EventBridge Rule Catching Dangerous Ingress Modification Anomalies
resource "aws_cloudwatch_event_rule" "network_sabotage_monitor" {
  name        = "capture-network-sabotage-attempts"
  description = "Intercepts unauthorized route table and gateway alterations at the infrastructure edge"

  event_pattern = jsonencode({
    "source": ["aws.ec2"],
    "detail-type": ["AWS API Call via CloudTrail"],
    "detail": {
      "eventSource": ["://amazonaws.com"],
      "eventName": [
        "CreateInternetGateway",
        "DeleteFlowLogs",
        "DisableVpcClassicLink"
      ]
    }
  })
}

# 3. Create the Secure IAM Execution Role for the Session Invalidator Engine
resource "aws_iam_role" "session_killer_role" {
  name = "DataCenter-Lambda-SessionKiller-ExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege tokens enabling the function to apply restrictive inline policies
resource "aws_iam_role_policy" "session_killer_privileges" {
  name = "Lambda-IAM-PutUserPolicy-SessionIsolation"
  role = aws_iam_role.session_killer_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:PutUserPolicy",
          "iam:PutRolePolicy"
        ]
        Resource = "*" # Session policies apply over active dynamic principal sessions account-wide
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = data.aws_sns_topic.soc_alert_node.arn
      }
    ]
  })
}

# 4. Deploy the Serverless Identity Circuit Breaker Function (AWS Lambda)
resource "aws_lambda_function" "session_circuit_breaker" {
  function_name = "Enterprise-Core-IAM-ActiveSessionCircuitBreaker"
  role          = aws_iam_role.session_killer_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "mock-session-killer.zip"
  timeout       = 30

  # Buildspec inline note: Real-time script that ingests the specific AssumedRoleSessionName,
  # generates an explicit Deny policy, and binds it straight into the active AWS STS token.
}

# 5. Connect the Monitoring Gate Directly to Invoke the Lambda Session Killer
resource "aws_cloudwatch_event_target" "bind_session_killer_target" {
  rule      = aws_cloudwatch_event_rule.network_sabotage_monitor.name
  target_id = "InvokeActiveSessionCircuitBreaker"
  arn       = aws_lambda_function.session_circuit_breaker.arn
}

# Allow EventBridge to Invoke the Lambda Function Natively
resource "aws_lambda_permission" "allow_eventbridge_session_trigger" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.session_circuit_breaker.function_name
  principal     = "://amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.network_sabotage_monitor.arn
}
