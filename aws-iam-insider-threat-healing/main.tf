# =====================================================================
# CERTIFICATION SCENARIO 108: AUTONOMOUS IDENTITY SELF-HEALING
# COMPONENT: EVENTBRIDGE REMEDIATIONS ISOLATING COMPROMISED ADMINISTRATORS
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

# 1. Reference Your Central Telemetry Anomaly Topic (From Phase 4 Core Network)
data "aws_sns_topic" "security_operations_alerts" {
  name = "enterprise-critical-root-access-alerts"
}

# 2. Architect the Autonomous EventBridge Sabotage Monitor Rule
resource "aws_cloudwatch_event_rule" "insider_threat_gate" {
  name        = "autonomous-identity-sabotage-detector"
  description = "Intercepts dangerous administrative operations to freeze the compromised identity instantly"

  # EVENT PATTERN: Watches global service planes for unauthorized destructive indicators
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
        "DeleteTrail",
        "StopLogging",
        "DeactivateMFADevice",
        "DeletePolicy",
        "LeaveOrganization"
      ]
    }
  })
}

# 3. Create the Secure IAM Execution Role for the Self-Healing Target Link
resource "aws_iam_role" "autonomous_remediation_role" {
  name = "DataCenter-EventBridge-InsiderThreatRemediation-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege tokens enabling the automation rules to spin up ssm runs
resource "aws_iam_role_policy" "remediation_privileges" {
  name = "EventBridge-IdentityRemediation-Runbook-Access"
  role = aws_iam_role.autonomous_remediation_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:StartAutomationExecution"
        ]
        Resource = "arn:aws:ssm:us-east-1::automation-definition/AWS-RevokeUnusedIAMUserCredentials:*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = data.aws_sns_topic.security_operations_alerts.arn
      }
    ]
  })
}

# 4. Bind EventBridge Directly to the Self-Healing SSM Runbook Target Block
resource "aws_cloudwatch_event_target" "ssm_lockdown_target" {
  rule      = aws_cloudwatch_event_rule.insider_threat_gate.name
  target_id = "TriggerInstantIAMCredentialLockdown"
  arn       = "arn:aws:ssm:us-east-1::automation-definition/AWS-RevokeUnusedIAMUserCredentials"
  role_arn  = aws_iam_role.autonomous_remediation_role.arn

  # Input Transformer: Dynamically extracts the offending user login name to feed the lock book
  input_transformer {
    input_paths = {
      "IAMUserId" = "$.detail.userIdentity.userName"
    }
    input_template = "{\"IAMUserId\": [<IAMUserId>]}"
  }
}

# 5. Simultaneously Route a High-Priority Alarm Event straight to the SOC
resource "aws_cloudwatch_event_target" "sns_threat_alert" {
  rule      = aws_cloudwatch_event_rule.insider_threat_gate.name
  target_id = "AlertSecurityOperationsOfActiveRemediation"
  arn       = data.aws_sns_topic.security_operations_alerts.arn
}
