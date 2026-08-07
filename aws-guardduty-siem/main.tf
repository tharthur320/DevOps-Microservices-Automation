# =====================================================================
# CERTIFICATION SCENARIO 30: CENTRALIZED LOGGING & THREAT INTELLIGENCE
# COMPONENT: AWS GUARDDUTY ORGANIZATION REPAIR & KINESIS STREAM LINKS
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Enable the Hardened AWS GuardDuty Threat Detection Engine Locally
resource "aws_guardduty_detector" "security_core_detector" {
  enable = true

  # Advanced Feature Logging Matrix Configuration
  datasources {
    s3_logs { enable = true }
    kubernetes {
      audit_logs { enable = true }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes { enable = true }
      }
    }
  }
}

# 2. Designate the Centralized Organizational Admin Account Configuration
# (This master switch gives your Security Account rights to manage child systems)
resource "aws_guardduty_organization_admin_account" "fms_admin" {
  admin_account_id = "888888888888" # Explicit 12-Digit Master Security Account ID
}

# 3. Deploy a High-Speed Amazon Kinesis Data Stream to Collect Incident Payloads
resource "aws_kinesis_stream" "threat_telemetry_bus" {
  name             = "enterprise-threat-indicators-stream"
  shard_count      = 2 # Horizontally partitions high-volume streaming telemetry data packets
  retention_period = 24

  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes"
  ]
}

# 4. Architect the EventBridge Security Rule Intercepting Critical Exploits
resource "aws_cloudwatch_event_rule" "guardduty_severity_filter" {
  name        = "capture-high-severity-guardduty-findings"
  description = "Intercepts GuardDuty machine learning findings with a severity score >= 7.0"

  # Event Pattern: Filters specifically for malicious compromise indicators flagged as High Severity
  event_pattern = jsonencode({
    "source": ["aws.guardduty"],
    "detail-type": ["GuardDuty Finding"],
    "detail": {
      "severity": [7, 7.0, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 7.9, 8, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9]
    }
  })
}

# 5. Connect the Event Bus Directly to Stream Findings to Kinesis Data Streams
resource "aws_cloudwatch_event_target" "kinesis_target" {
  rule      = aws_cloudwatch_event_rule.guardduty_severity_filter.name
  target_id = "StreamToSecurityAnalysisCluster"
  arn       = aws_kinesis_stream.threat_telemetry_bus.arn
  role_arn  = aws_iam_role.eventbridge_kinesis_execution_role.arn
}

# 6. Create the Secure IAM Role Allowing EventBridge to Write to Kinesis
resource "aws_iam_role" "eventbridge_kinesis_execution_role" {
  name = "DataCenter-EventBridge-Kinesis-ThreatStreamer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}
