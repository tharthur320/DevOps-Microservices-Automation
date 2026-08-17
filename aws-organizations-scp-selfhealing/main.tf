# =====================================================================
# CERTIFICATION SCENARIO 110: ORGANIZATIONAL SELF-DEFENDING FENCES
# COMPONENT: EVENTBRIDGE & LAMBDA TRIGGERING AUTOMATED CROSS-ACCOUNT SCP LOCKS
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
  region = "us-east-1" # Deployed exclusively inside your AWS Organizations Management Root Account
}

# 1. Reference Your Central Anomaly Communication Channels (From Phase 4 Core Network)
data "aws_sns_topic" "soc_priority_alerts" {
  name = "enterprise-critical-root-access-alerts"
}

# 2. Architect the Multi-Account Organizational Sabotage Monitor Gate
resource "aws_cloudwatch_event_rule" "organization_sabotage_monitor" {
  name        = "autonomous-organizational-sabotage-detector"
  description = "Intercepts destructive API mutations across child accounts to isolate the account natively via SCP"

  # EVENT PATTERN: Scans the organization event bus for severe cross-account compromise indicators
  event_pattern = jsonencode({
    "source": ["aws.cloudtrail"],
    "detail-type": ["AWS API Call via CloudTrail"],
    "detail": {
      "eventSource": [
        "://amazonaws.com",
        "://amazonaws.com",
        "://amazonaws.com"
      ],
      "eventName": [
        "DeleteOrganization",
        "LeaveOrganization",
        "DisableKey",
        "DeleteNetworkFirewall"
      ]
    }
  })
}

# 3. Create the Secure IAM Execution Role for the Global Organization Auto-Locksmith
resource "aws_iam_role" "scp_locksmith_role" {
  name = "DataCenter-Lambda-OrganizationalSCPLocksmith-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege tokens enabling the serverless role to attach global organizational policies
resource "aws_iam_role_policy" "scp_locksmith_privileges" {
  name = "Lambda-Organizations-SCPMutation-Access"
  role = aws_iam_role.scp_locksmith_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "organizations:CreatePolicy",
          "organizations:AttachPolicy",
          "organizations:DescribeAccount",
          "organizations:ListPolicies"
        ]
        Resource = "*" # Organizational control plane modifications operate globally across account trees
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["sns:Publish"]
        Resource = data.aws_sns_topic.soc_priority_alerts.arn
      }
    ]
  })
}

# 4. Deploy the Serverless Organizational Locksmith Worker (AWS Lambda)
resource "aws_lambda_function" "scp_locksmith_worker" {
  function_name = "Enterprise-Core-Organizations-SCPLocksmith"
  role          = aws_iam_role.scp_locksmith_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "mock-scp-locksmith.zip"
  timeout       = 30

  # Buildspec inline note: Real-time worker code that extracts the offending account ID, 
  # compiles an explicit DenyAll SCP document, and attaches it straight to the account root dynamically.
}

# 5. Connect the Monitoring Gate Directly to Invoke the Lambda Locksmith Target
resource "aws_cloudwatch_event_target" "bind_locksmith_target" {
  rule      = aws_cloudwatch_event_rule.organization_sabotage_monitor.name
  target_id = "InvokeOrganizationalSCPLocksmith"
  arn       = aws_lambda_function.scp_locksmith_worker.arn
}

# Allow EventBridge to Invoke the Lambda Function Natively
resource "aws_lambda_permission" "allow_eventbridge_organizations_trigger" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scp_locksmith_worker.function_name
  principal     = "://amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.organization_sabotage_monitor.arn
}
