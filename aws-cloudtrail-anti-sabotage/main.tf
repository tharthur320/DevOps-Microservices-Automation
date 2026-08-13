# =====================================================================
# CERTIFICATION SCENARIO 99: SELF-HEALING ANTI-SABOTAGE PERIMETERS
# COMPONENT: EVENTBRIDGE SECURITY REPAIR RULES RESTORING AUDIT TRAILS
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
  region = "us-east-1" # Deployed inside your central organization management account
}

# 1. Reference Your Existing Governance Communication Switchboard (From Scenario 36)
data "aws_sns_topic" "critical_incident_alerts" {
  name = "enterprise-critical-root-access-alerts"
}

# 2. Architect the EventBridge Rule Intercepting Audit Trailing Deletion Attempts
resource "aws_cloudwatch_event_rule" "cloudtrail_sabotage_monitor" {
  name        = "capture-and-repair-cloudtrail-sabotage"
  description = "Intercepts API payloads attempting to stop, disable, or delete governance trails"

  # EVENT PATTERN: Intercepts destructive CloudTrail system write parameters via global CloudTrail logs
  event_pattern = jsonencode({
    "source": ["aws.cloudtrail"],
    "detail-type": ["AWS API Call via CloudTrail"],
    "detail": {
      "eventSource": ["://amazonaws.com"],
      "eventName": [
        "DeleteTrail",
        "StopLogging",
        "UpdateTrail"
      ]
    }
  })
}

# 3. Create the Secure IAM Execution Role for the Self-Healing Trigger
resource "aws_iam_role" "sabotage_remediation_role" {
  name = "DataCenter-EventBridge-TrailRemediation-RunnerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege tokens enabling the automation engine to start runbooks
resource "aws_iam_role_policy" "remediaiton_invocation_privileges" {
  name = "EventBridge-Remediation-Runbook-Access"
  role = aws_iam_role.sabotage_remediation_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:StartAutomationExecution"
        ]
        Resource = "arn:aws:ssm:us-east-1::automation-definition/AWS-EnableAWSCloudTrail:*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = data.aws_sns_topic.critical_incident_alerts.arn
      }
    ]
  })
}

# 4. Bind EventBridge Directly to the Self-Healing SSM Runbook Target
resource "aws_cloudwatch_event_target" "ssm_restore_target" {
  rule      = aws_cloudwatch_event_rule.cloudtrail_sabotage_monitor.name
  target_id = "TriggerCloudTrailLoggingRestoration"
  arn       = "arn:aws:ssm:us-east-1::automation-definition/AWS-EnableAWSCloudTrail"
  role_arn  = aws_iam_role.sabotage_remediation_role.arn

  # Input Transformer: Dynamically parse and feed the broken trail name straight into the runbook
  input_transformer {
    input_paths = {
      "TrailName" = "$.detail.requestParameters.name"
    }
    input_template = "{\"TrailName\": [<TrailName>]}"
  }
}

# 5. Simultaneously Route a High-Priority Alarm Alert Event straight to the SOC
resource "aws_cloudwatch_event_target" "sns_sabotage_alert" {
  rule      = aws_cloudwatch_event_rule.cloudtrail_sabotage_monitor.name
  target_id = "AlertSecurityOperationsOfSabotage"
  arn       = data.aws_sns_topic.critical_incident_alerts.arn
}
