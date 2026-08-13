# =====================================================================
# CERTIFICATION SCENARIO 91: DYNAMIC EDGE THREAT MITIGATION
# COMPONENT: CLOUDWATCH LOG INSIGHTS UPDATING WAFV2 IP BLACKLISTS
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

# 1. Provision the Dynamic Edge IP Set Container (The Active Blacklist Vault)
resource "aws_wafv2_ip_set" "dynamic_blacklist" {
  name               = "enterprise-dynamic-threat-blacklist"
  description        = "Dynamic perimeter IP blacklist updated automatically via log parsing telemetry"
  scope              = "REGIONAL" # Placed in front of regional Application Load Balancers
  ip_address_version = "IPV4"

  # INITIAL STATE: Starts empty and populates dynamically via our automation worker
  addresses          = [] 

  lifecycle {
    ignore_changes = [addresses] # Prevents Terraform from wiping out live auto-detected IPs on successive runs
  }

  tags = {
    Layer      = "Perimeter-Threat-Isolation"
    SavedAsset = "True"
  }
}

# 2. Create the Secure IAM Execution Role for the Threat Hunter Engine
resource "aws_iam_role" "threat_hunter_role" {
  name = "DataCenter-WAF-ThreatHunter-ExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege tokens enabling the role to query logs and update WAF IP configurations
resource "aws_iam_role_policy" "threat_hunter_privileges" {
  name = "Lambda-WAF-IPSet-Update-Privileges"
  role = aws_iam_role.threat_hunter_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "wafv2:GetIPSet",
          "wafv2:UpdateIPSet"
        ]
        Resource = aws_wafv2_ip_set.dynamic_blacklist.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:StartQuery",
          "logs:GetQueryResults",
          "logs:DescribeLogGroups"
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

# 3. Deploy the Serverless Threat Hunter Script (AWS Lambda Log Insights Runner)
resource "aws_lambda_function" "threat_hunter_worker" {
  function_name = "Enterprise-Core-WAF-LogInsightsThreatHunter"
  role          = aws_iam_role.threat_hunter_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "mock-threat-hunter.zip"
  timeout       = 60 # 60-second window to allow complex log parsing queries to finish

  environment {
    variables = {
      TARGET_WAF_IPSET_ARN  = aws_wafv2_ip_set.dynamic_blacklist.arn
      TARGET_WAF_IPSET_ID   = aws_wafv2_ip_set.dynamic_blacklist.id
      TARGET_WAF_IPSET_NAME = aws_wafv2_ip_set.dynamic_blacklist.name
    }
  }
}

# 4. Architect the 5-Minute Cron Trigger (EventBridge Scheduled Compliance Event Rule)
resource "aws_cloudwatch_event_rule" "threat_hunter_clock" {
  name                = "trigger-threat-hunter-every-5-minutes"
  description         = "Triggers log insights parsing and automated perimeter blacklisting blocks"
  schedule_expression = "rate(5 minutes)" # Continuous evaluation cycle
}

# 5. Bind the Chronological Rule Directly to Invoke the Lambda Threat Hunter
resource "aws_cloudwatch_event_target" "bind_threat_target" {
  rule      = aws_cloudwatch_event_rule.threat_hunter_clock.name
  target_id = "InvokeLogInsightsThreatHunter"
  arn       = aws_lambda_function.threat_hunter_worker.arn
}

# Allow EventBridge to Invoke the Lambda Function Natively
resource "aws_lambda_permission" "allow_eventbridge_threat_trigger" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.threat_hunter_worker.function_name
  principal     = "://amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.threat_hunter_clock.arn
}
