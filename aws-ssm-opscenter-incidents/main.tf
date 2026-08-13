# =====================================================================
# CERTIFICATION SCENARIO 80: AUTOMATED INCIDENT LIFE CYCLE TRACKING
# COMPONENT: EVENTBRIDGE & LAMBDA ENGAGING SSM OPSCENTER TICKETS
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

# 1. Create the Secure IAM Execution Role for the Incident Registration Engine
resource "aws_iam_role" "opscenter_runner_role" {
  name = "DataCenter-OpsCenter-IncidentRunner-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege privileges to allow OpsItem ticket registration
resource "aws_iam_role_policy" "opscenter_registration_privileges" {
  name = "Lambda-SSM-OpsCenter-Registration-Access"
  role = aws_iam_role.opscenter_runner_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:CreateOpsItem"
        ]
        Resource = "*" # OpsItems are global structural account control plane parameters
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}

# 2. Deploy the Serverless Incident Registry Script (AWS Lambda)
resource "aws_lambda_function" "opscenter_worker" {
  function_name = "Enterprise-Core-SSMOpsCenter-IncidentRegistrar"
  role          = aws_iam_role.opscenter_runner_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "mock-opscenter-registrar.zip"
  timeout       = 30

  # Buildspec inline concept: Real-time Javascript handler that reads an incoming 
  # CloudWatch alarm payload and structures the exact mandatory fields for the OpsItem API.
}

# 3. Architect the EventBridge Monitor Capturing Production Compute Failures
resource "aws_cloudwatch_event_rule" "compute_failure_monitor" {
  name        = "capture-production-compute-failures"
  description = "Intercepts severe high-concurrency or system drop failure states across core networks"

  # Event Pattern: Filters explicitly for production target tracking alarm triggers
  event_pattern = jsonencode({
    "source": ["aws.cloudwatch"],
    "detail-type": ["CloudWatch Alarm State Change"],
    "detail": {
      "state": {
        "value": ["ALARM"]
      }
    }
  })
}

# 4. Bind the Monitoring Gate Directly to Invoke the Lambda Incident Registar
resource "aws_cloudwatch_event_target" "bind_incident_target" {
  rule      = aws_cloudwatch_event_rule.compute_failure_monitor.name
  target_id = "InvokeOpsCenterIncidentRegistrar"
  arn       = aws_lambda_function.opscenter_worker.arn
}

# Allow EventBridge to Invoke the Lambda Function Natively
resource "aws_lambda_permission" "allow_eventbridge_incident_trigger" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.opscenter_worker.function_name
  principal     = "://amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.compute_failure_monitor.arn
}
