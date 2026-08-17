# =====================================================================
# CERTIFICATION SCENARIO 136: SOVEREIGN REPRODUCTIVE CRYPTOGRAPHY
# COMPONENT: AWS EXTERNAL KEYS TRACKING AUTOMATED EXPIRATION ALARMS
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
data "aws_sns_topic" "security_ops_alerts" {
  name = "enterprise-critical-root-access-alerts"
}

# 2. Provision the Empty External KMS Key Container Wrapper (BYOK Shell)
resource "aws_kms_external_key" "byok_secure_shell" {
  description             = "Sovereign Customer-Managed External Key Container for BYOK Importation"
  deletion_window_in_days = 7
  enabled                 = true

  # KEY MATERIAL LIFECYCLE CONTROLS: Force an immutable expiration timeline
  # In an automated orchestration pipeline, this date is injected dynamically via deployment variables
  valid_to                = "2027-04-15T12:00:00Z" 

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountKeyManagement"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::123456789012:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = {
    Layer      = "Sovereign-Cryptographic-Boundary"
    SavedAsset = "True"
  }
}

resource "aws_kms_alias" "byok_key_alias" {
  name          = "alias/enterprise-sovereign-byok-key"
  target_key_id = aws_kms_external_key.byok_secure_shell.id
}

# 3. Deploy a CloudWatch Metric Alarm Tracking External Key Expiration Thresholds
resource "aws_cloudwatch_metric_alarm" "byok_expiration_warning" {
  alarm_name          = "CRITICAL-SECURITY-KMS-BYOK-EXPIRATION-ALERT"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DaysToExpiry" # Native AWS metric tracking external imported key lifetimes
  namespace           = "AWS/KMS"
  period              = "86400" # Sample key expiration parameters once every 24 hours (86400 seconds)
  statistic           = "Minimum"
  threshold           = "15" # Trigger the alarm 15 days before the hard key block drops
  alarm_description   = "Immediate action required: Imported BYOK cryptographic key material is approaching its expiration window."

  dimensions = {
    KeyId = aws_kms_external_key.byok_secure_shell.id
  }
}

# 4. Connect the Monitoring Alarm State Change Directly to Invoke Security Alert Paths
resource "aws_cloudwatch_event_rule" "byok_alarm_trigger_rule" {
  name        = "capture-byok-expiration-metric-alarms"
  description = "Intercepts CloudWatch cryptographic alarms indicating external imported key expiration risks"

  event_pattern = jsonencode({
    "source": ["aws.cloudwatch"],
    "detail-type": ["CloudWatch Alarm State Change"],
    "detail": {
      "alarmName": [aws_cloudwatch_metric_alarm.byok_expiration_warning.name],
      "state": {
        "value": ["ALARM"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "bind_byok_alert_target" {
  rule      = aws_cloudwatch_event_rule.byok_alarm_trigger_rule.name
  target_id = "StreamBYOKBreachToSecurityOperations"
  arn       = data.aws_sns_topic.security_ops_alerts.arn
}
