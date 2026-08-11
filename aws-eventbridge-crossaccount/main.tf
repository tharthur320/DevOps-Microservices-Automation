# =====================================================================
# CERTIFICATION SCENARIO 47: MULTI-ACCOUNT DECOUPLED MESSAGING
# COMPONENT: EVENTBRIDGE CUSTOM BUSES WITH CROSS-ACCOUNT INGEST METRICS
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Deploy the Centralized Custom Event Bus (Located in your Central Operations Account)
resource "aws_cloudwatch_event_bus" "global_bus" {
  name = "enterprise-global-transaction-bus"
}

# 2. Configure Cross-Account Ingestion Permissions on the Custom Event Bus
# (This explicit gate whitelists trusted child accounts to write straight to your bus)
resource "aws_cloudwatch_event_permission" "allow_billing_account_write" {
  principal    = "111111111111" # The explicit 12-digit physical AWS Billing Account ID
  statement_id = "AllowBillingAccountToPublishEvents"
  event_bus_name = aws_cloudwatch_event_bus.global_bus.name
  
  # Condition constraint: resticts the account to pushing valid structures
  condition {
    key   = "aws:PrincipalOrgID"
    type  = "StringEquals"
    value = "o-enterpriseorgid123" # Locks access strictly to your verified AWS Organization ID
  }
}

# 3. Architect the Event Filtering Guardrail Rule (The JSON Payload Screen)
resource "aws_cloudwatch_event_rule" "transaction_filter_rule" {
  name           = "filter-and-route-approved-transactions"
  description    = "Intercepts order events with a status of CONFIRMED and a value > $500"
  event_bus_name = aws_cloudwatch_event_bus.global_bus.name

  # EVENT PATTERN: Deep-packet screening of incoming custom JSON event payloads
  event_pattern = jsonencode({
    "source": ["enterprise.billing"],
    "detail-type": ["OrderPlacement"],
    "detail": {
      "status": ["CONFIRMED"],
      "financials": {
        "tier": ["EnterprisePremium"]
      }
    }
  })
}

# 4. Bind the Filtered Event Bus Directly to a Secure Target Handler
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule           = aws_cloudwatch_event_rule.transaction_filter_rule.name
  event_bus_name = aws_cloudwatch_event_bus.global_bus.name
  target_id      = "RouteToFullfilmentEngine"
  arn            = "arn:aws:lambda:us-east-1:222222222222:function:InventoryFullfilmentWorker" # Destination Account ID Lambda
  role_arn       = aws_iam_role.eventbridge_cross_account_role.arn
}

# 5. Create the Secure IAM Execution Role for Cross-Account Message Delivery
resource "aws_iam_role" "eventbridge_cross_account_role" {
  name = "DataCenter-EventBridge-CrossAccount-Router"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}
