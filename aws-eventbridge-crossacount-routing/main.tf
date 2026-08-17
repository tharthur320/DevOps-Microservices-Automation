# =====================================================================
# CERTIFICATION SCENARIO 141: MULTI-ACCOUNT EVENT INGESTION MESHES
# COMPONENT: EVENTBRIDGE GLOBAL BUSES UTILIZING ORGANIZATIONAL POLICIES
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
  region = "us-east-1" # Deployed inside your Central Security Operations Account (123456789012)
}

# 1. Provision the Master Global Event Ingestion Bus (The Security Hub Ingestor)
resource "aws_cloudwatch_event_bus" "central_security_bus" {
  name = "enterprise-central-security-event-bus"
}

# 2. Architect the Authoritative Cross-Account Organizational Resource Policy
# (Enforces native, un-bypassable trust across your entire multi-account organization tree)
resource "aws_cloudwatch_event_bus_policy" "organization_trust_policy" {
  event_bus_name = aws_cloudwatch_event_bus.central_security_bus.name
  statement_id   = "AllowAllChildAccountsInOrganizationToPutEvents"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowOrgChildAccountIngress"
      Effect    = "Allow"
      Principal = "*" # Wildcard principal is safely constrained by our Org ID filter below
      Action    = "events:PutEvents"
      Resource  = aws_cloudwatch_event_bus.central_security_bus.arn
      Condition = {
        StringEquals = {
          "aws:PrincipalOrgID" = "o-xxxxxxxxxx" # Injected dynamically via your organization metadata tokens
        }
      }
    }]
  })
}

# =====================================================================
# SPOKE ACCOUNT BLUEPRINT: CROSS-ACCOUNT EVENT FORWARDING RULE
# =====================================================================
# This secondary block is what you deploy inside EACH child app account
# to capture local infrastructure alerts and route them straight to the hub.

/*
resource "aws_cloudwatch_event_rule" "local_anomaly_monitor" {
  name        = "forward-local-anomalies-to-central-hub"
  description = "Captures local infrastructure exceptions to stream across the account boundary"
  event_pattern = jsonencode({
    "source": ["aws.config", "aws.iam"],
    "detail-type": ["Config Rules Compliance Change", "AWS API Call via CloudTrail"]
  })
}

resource "aws_cloudwatch_event_target" "forward_to_central_bus" {
  rule      = aws_cloudwatch_event_rule.local_anomaly_monitor.name
  target_id = "RouteToCentralSecurityBus"
  arn       = "arn:aws:events:us-east-1:123456789012:event-bus/enterprise-central-security-event-bus"
  role_arn  = "arn:aws:iam::888888888888:role/DataCenter-EventBridge-CrossAccountForwarding-Role"
}
*/
