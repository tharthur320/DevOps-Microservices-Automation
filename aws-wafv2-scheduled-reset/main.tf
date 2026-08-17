# =====================================================================
# CERTIFICATION SCENARIO 130: SELF-CLEARING EDGE CAPACITY HARDENING
# COMPONENT: EVENTBRIDGE CRONS AUTOMATICALLY FLUSHING WAFV2 IP SETS
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

# 1. Provision the High-Capacity Dynamic IP Set Container (The Active Blacklist Vault)
resource "aws_wafv2_ip_set" "temporary_blacklist" {
  name               = "enterprise-temporary-threat-blacklist"
  description        = "High-capacity perimeter IP set container flushed automatically every 24 hours"
  scope              = "REGIONAL" # Placed directly in front of regional load balancers
  ip_address_version = "IPV4"

  # INITIAL STATE: Starts empty and handles programmatic runtime modifications
  addresses          = [] 

  lifecycle {
    ignore_changes = [addresses] # Prevents Terraform from wiping out live auto-blocked IPs on successive runs
  }

  tags = {
    Layer      = "Edge-Capacity-Governance"
    SavedAsset = "True"
  }
}

# 2. Create the Secure IAM Execution Role for the Perimeter Janitor Engine
resource "aws_iam_role" "perimeter_janitor_role" {
  name = "DataCenter-WAF-PerimeterJanitor-ExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege tokens enabling the role to modify and clear WAF IP sets
resource "aws_iam_role_policy" "perimeter_janitor_privileges" {
  name = "Lambda-WAF-IPSet-Clear-Privileges"
  role = aws_iam_role.perimeter_janitor_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "wafv2:GetIPSet",
          "wafv2:UpdateIPSet"
        ]
        Resource = aws_wafv2_ip_set.temporary_blacklist.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}

# 3. Deploy the Serverless Perimeter Janitor Worker Function (AWS Lambda)
resource "aws_lambda_function" "perimeter_janitor_worker" {
  function_name = "Enterprise-Core-WAF-IPSetJanitor"
  role          = aws_iam_role.perimeter_janitor_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "mock-perimeter-janitor.zip"
  timeout       = 30

  environment {
    variables = {
      TARGET_WAF_IPSET_ARN  = aws_wafv2_ip_set.temporary_blacklist.arn
      TARGET_WAF_IPSET_ID   = aws_wafv2_ip_set.temporary_blacklist.id
      TARGET_WAF_IPSET_NAME = aws_wafv2_ip_set.temporary_blacklist.name
    }
  }
}

# 4. Architect the 24-Hour Nightly Cron Clock (EventBridge Scheduled Compliance Event Rule)
resource "aws_cloudwatch_event_rule" "janitor_clock" {
  name                = "trigger-perimeter-janitor-nightly"
  description         = "Triggers a full programmatic flush of the temporary WAF block list every 24 hours"
  schedule_expression = "cron(0 2 * * ? *)" # Automated execution cycle every night at 2:00 AM UTC
}

# 5. Bind the Chronological Rule Directly to Invoke the Lambda Perimeter Janitor
resource "aws_cloudwatch_event_target" "bind_janitor_target" {
  rule      = aws_cloudwatch_event_rule.janitor_clock.name
  target_id = "InvokeWAFIPSetJanitor"
  arn       = aws_lambda_function.perimeter_janitor_worker.arn
}

# Allow EventBridge to Invoke the Lambda Function Natively
resource "aws_lambda_permission" "allow_eventbridge_janitor_trigger" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.perimeter_janitor_worker.function_name
  principal     = "://amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.janitor_clock.arn
}
