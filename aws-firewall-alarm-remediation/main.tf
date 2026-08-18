# =====================================================================
# CERTIFICATION SCENARIO 173: ADAPTIVE NETWORK SELF-HEALING PERIMETERS
# COMPONENT: CLOUDWATCH ALARMS INVOICING LAMBDA TO RECONFIG NETWORK RULES
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

# 1. Reference Your Central Active Network Firewall Appliance (From Scenario 61)
data "aws_networkfirewall_firewall" "perimeter_shield" {
  name = "enterprise-data-center-network-firewall"
}

# 2. Deploy the CloudWatch Metric Alarm Tracking Network Firewall Anomalies
resource "aws_cloudwatch_metric_alarm" "firewall_threat_alarm" {
  alarm_name          = "CRITICAL-NETWORK-FIREWALL-THREAT-ANOMALY-ALERT"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DroppedPackets" # Track total dropped packets to catch active intrusion spikes
  namespace           = "AWS/NetworkFirewall"
  period              = "60" # Evaluate edge telemetry parameters every 60 seconds
  statistic           = "Sum"
  threshold           = "1000" # Trigger if drops surge past 1,000 packets per minute
  alarm_description   = "Autonomous metric alarm monitoring aggregate perimeter threat vectors to trigger network isolation."

  dimensions = {
    FirewallName = data.aws_networkfirewall_firewall.perimeter_shield.name
    Region       = "us-east-1"
  }
}

# 3. Create the Secure IAM Execution Role for the Adaptive Threat Engine
resource "aws_iam_role" "adaptive_network_threat_role" {
  name = "DataCenter-NetworkFirewall-AdaptiveThreatEngine-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege tokens enabling the function to modify security parameters
resource "aws_iam_role_policy" "adaptive_network_threat_privileges" {
  name = "Lambda-Network-SecurityGroup-Update-Privileges"
  role = aws_iam_role.adaptive_network_threat_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeSecurityGroups",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupIngress"
        ]
        Resource = "*" # Applied across corporate ingress security groups to isolate attackers
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}

# 4. Deploy the Serverless Adaptive Network Isolation Script (AWS Lambda)
resource "aws_lambda_function" "network_isolation_worker" {
  function_name = "Enterprise-Core-NetworkFirewall-AdaptiveIsolator"
  role          = aws_iam_role.adaptive_network_threat_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "mock-network-isolator.zip"
  timeout       = 30

  environment {
    variables = {
      TARGET_FIREWALL_ARN = data.aws_networkfirewall_firewall.perimeter_shield.arn
    }
  }
}

# 5. Connect the Monitoring Alarm State Change Directly to Invoke the Lambda Isolator
resource "aws_cloudwatch_event_rule" "network_anomaly_trigger_rule" {
  name        = "capture-firewall-metric-alarms"
  description = "Intercepts CloudWatch perimeter alarms indicating active packet injection or brute-force attacks"

  event_pattern = jsonencode({
    "source": ["aws.cloudwatch"],
    "detail-type": ["CloudWatch Alarm State Change"],
    "detail": {
      "alarmName": [aws_cloudwatch_metric_alarm.firewall_threat_alarm.name],
      "state": {
        "value": ["ALARM"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "bind_isolator_target" {
  rule      = aws_cloudwatch_event_rule.network_anomaly_trigger_rule.name
  target_id = "InvokeNetworkAdaptiveIsolator"
  arn       = aws_lambda_function.network_isolation_worker.arn
}

# Allow EventBridge to Invoke the Lambda Function Natively
resource "aws_lambda_permission" "allow_eventbridge_isolator" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.network_isolation_worker.function_name
  principal     = "://amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.network_anomaly_trigger_rule.arn
}
