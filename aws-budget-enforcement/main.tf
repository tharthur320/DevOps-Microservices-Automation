# =====================================================================
# CERTIFICATION SCENARIO 28: AUTOMATED FINANCIAL COMPLIANCE GOVERNANCE
# COMPONENT: AWS BUDGET ACCENTS & SNSRemediation AUTOMATION LOOPS
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Deploy the Centralized SNS Notification Switchboard for Cost Containment
resource "aws_sns_topic" "budget_alerts" {
  name = "enterprise-cost-threshold-alerts"
}

# 2. Architect the Enterprise Cost Governance Guardrail (AWS Budget)
resource "aws_budgets_budget" "monthly_operational_budget" {
  name              = "enterprise-monthly-datacenter-budget"
  budget_type       = "COST"
  limit_amount      = "5000" # Absolute maximum monthly cost threshold parameters ($5,000 USD)
  limit_unit        = "USD"
  time_unit         = "MONTHLY"

  # COST FILTERS: Group and monitor spend across all infrastructure systems
  cost_filter {
    name = "LinkedAccount"
    values = [
      "111111111111", # Production Hosting Account ID
      "222222222222"  # DevOps Tooling Account ID
    ]
  }

  # TRIGGER 1: Alert if forecasted expenditure crosses 90% of the limit
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 90
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_sns_topic_arns = [aws_sns_topic.budget_alerts.arn]
  }

  # TRIGGER 2: Alert if actual expenditure crosses 100% of the limit
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.budget_alerts.arn]
  }
}

# 3. Create the Secure IAM Execution Role for the Financial Remediation Engine
resource "aws_iam_role" "budget_remediation_role" {
  name = "DataCenter-Budget-Remediation-Runner"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# 4. Attach an Action Policy to Automate Environment Containment
# (This instructs the engine to restrict permissions when the budget is breached)
resource "aws_iam_role_policy" "budget_containment_policy" {
  name = "Budget-Containment-Privileges"
  role = aws_iam_role.budget_remediation_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:StopInstances",
          "ec2:DescribeInstances",
          "iam:PutRolePolicy"
        ]
        Resource = "*"
      }
    ]
  })
}
