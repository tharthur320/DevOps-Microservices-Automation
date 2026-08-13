# =====================================================================
# CERTIFICATION SCENARIO 79: SOVEREIGN REPRODUCTIVE DATA PROTECTION
# COMPONENT: AWS EXTERNAL KEY CONTAINERS MAPPED TO IMPORT LIFE CYCLES
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

# 1. Provision the Empty External KMS Key Container Wrapper (BYOK Shell)
resource "aws_kms_external_key" "byok_external_key" {
  description             = "Sovereign Customer-Managed External Key Container for BYOK Importation"
  deletion_window_in_days = 7
  enabled                 = true

  # KEY MATERIAL LIFECYCLE CONTROLS: Force an immutable expiration timeline
  # In production, this data variable is calculated and passed dynamically via deployment variables
  valid_to                = "2027-02-13T12:00:00Z" 

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountManagement"
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

# 2. Deploy a CloudWatch Metric Alarm Tracking External Key Expiration Thresholds
resource "aws_cloudwatch_metric_alarm" "key_expiration_warning" {
  alarm_name          = "CRITICAL-SECURITY-KMS-IMPORT-KEY-EXPIRATION-WARNING"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DaysToExpiry" # Native AWS metric tracking external imported key lifetimes
  namespace           = "AWS/KMS"
  period              = "86400" # Sample key expiration parameters once every 24 hours (86400 seconds)
  statistic           = "Minimum"
  threshold           = "15" # Trigger the alarm 15 days before the hard key block drops
  alarm_description   = "Immediate action required: Imported key material is approaching its expiration window."

  dimensions = {
    KeyId = aws_kms_external_key.byok_external_key.id
  }

  # ACTION TARGET MAPPING: Route the metric warning straight to your active security teams
  alarm_actions = ["arn:aws:sns:us-east-1:123456789012:enterprise-infrastructure-anomaly-alerts"]
}
