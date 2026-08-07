# =====================================================================
# CERTIFICATION SCENARIO 36: REAL-TIME TELEMETRY AUDITING & THREAT ALERTS
# COMPONENT: CLOUDWATCH LOG METRIC FILTERS EXTRACTION MAPPED TO SNS TOPICS
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Reference Your Centralized CloudTrail Log Destination Group
# (This binds the metric filter straight to your Phase 4 active logging streams)
resource "aws_cloudwatch_log_group" "cloudtrail_log_group" {
  name              = "enterprise-security-governance-audit-logs"
  retention_in_days = 90
}

# 2. Architect the Hardened CloudWatch Log Metric Filter Tracking Root Identity Use
resource "aws_cloudwatch_log_metric_filter" "root_activity_filter" {
  name           = "ExtractRootUserActivitySignatures"
  log_group_name = aws_cloudwatch_log_group.cloudtrail_log_group.name
  
  # REGEX JSON FILTER PATTERN: Matches when the identity type is exactly Root
  # and filters out normal internal service invocations to prevent false alarms
  pattern        = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS }"

  metric_transformation {
    name      = "RootAccountActionCount"
    namespace = "CloudTrailSecurityMetrics"
    value     = "1" # Add exactly +1 to the metric count the millisecond a match occurs
  }
}

# 3. Deploy the High-Priority Amazon SNS Incident Response Alert Topic
resource "aws_sns_topic" "security_incident_alerts" {
  name = "enterprise-critical-root-access-alerts"
}

# 4. Deploy the Metric Alarm to Catch and Fire Root Action Events Instantly
resource "aws_cloudwatch_metric_alarm" "root_use_alarm" {
  alarm_name          = "CRITICAL-SECURITY-BREACH-ROOT-ACCOUNT-ACTIVITY-DETECTED"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = aws_cloudwatch_log_metric_filter.root_activity_filter.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.root_activity_filter.metric_transformation[0].namespace
  period              = "60" # Check for root activity signatures every 60 seconds
  statistic           = "Sum"
  threshold           = "0" # Fire the alarm instantly if the counter ticks to 1 or higher
  alarm_description   = "Immediate action required: Unauthorized API actions executed using Root credentials."

  # ACTION TARGET MAPPING: Direct the alarm state straight to your incident response channels
  alarm_actions = [aws_sns_topic.security_incident_alerts.arn]

  tags = {
    Severity   = "Critical-P1"
    SavedAsset = "True"
  }
}
