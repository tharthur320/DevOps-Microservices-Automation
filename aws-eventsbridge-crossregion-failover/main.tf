# =====================================================================
# CERTIFICATION SCENARIO 151: EVENT-DRIVEN RESILIENCE AND RECOVERY
# COMPONENT: EVENTBRIDGE BUSES STREAMS AUTONOMOUS CROSS-REGION FORWARDING
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
  region = "us-east-1" # Deployed inside your Primary Application Account (Virginia)
}

# 1. Provision the Primary Event Ingestion Bus (The Local Active Application Core)
resource "aws_cloudwatch_event_bus" "local_application_bus" {
  name = "enterprise-core-application-bus"
}

# 2. Create the Secure IAM Execution Role for the Cross-Region Ingestion Bridge
resource "aws_iam_role" "eventbridge_crossregion_role" {
  name = "DataCenter-EventBridge-CrossRegionFailover-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege tokens enabling the local bus to push events across regions
resource "aws_iam_role_policy" "eventbridge_crossregion_policy" {
  name = "EventBridge-CrossRegion-DataPlane-PutEvents"
  role = aws_iam_role.eventbridge_crossregion_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "events:PutEvents"
      Resource = "arn:aws:events:us-west-2:123456789012:event-bus/enterprise-dr-standby-bus" # Oregon Standby Target Bus ARN
    }]
  })
}

# 3. Architect the EventBridge Capture Rule Filtering P1 System Anomaly Indicators
resource "aws_cloudwatch_event_rule" "anomaly_failover_rule" {
  name           = "autonomous-crossregion-anomaly-failover"
  description    = "Intercepts critical transactional errors to mirror them down to the disaster recovery region"
  event_bus_name = aws_cloudwatch_event_bus.local_application_bus.name

  event_pattern = jsonencode({
    "source": ["enterprise.commerce.orders"],
    "detail-type": ["Transaction Execution Failure"],
    "detail": {
      "severity": ["CRITICAL", "P1"]
    }
  })
}

# 4. Bind the Monitoring Gate Directly to Invoke the Cross-Region Standby Destination
resource "aws_cloudwatch_event_target" "forward_to_oregon_standby" {
  event_bus_name = aws_cloudwatch_event_bus.local_application_bus.name
  rule           = aws_cloudwatch_event_rule.anomaly_failover_rule.name
  target_id      = "RouteToOregonStandbyBus"
  arn            = "arn:aws:events:us-west-2:123456789012:event-bus/enterprise-dr-standby-bus"
  role_arn       = aws_iam_role.eventbridge_crossregion_role.arn

  # Buffer Configuration: Retry delivery failures for up to 2 hours to protect data plane integrity
  retry_policy {
    maximum_event_age_in_seconds = 7200
    maximum_retry_attempts       = 100
  }
}
