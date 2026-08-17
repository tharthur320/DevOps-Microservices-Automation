# =====================================================================
# CERTIFICATION SCENARIO 123: ADAPTIVE EDGE DEFENSE REMEDIATIONS
# COMPONENT: CLOUDWATCH ALARMS INVOICING LAMBDA TO OVERRIDE WAFV2 RULES
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

# 1. Reference Your Foundational Layer-7 Edge Perimeter (From Scenario 107)
data "aws_wafv2_web_acl" "ingress_shield" {
  name  = "enterprise-autonomous-edge-perimeter"
  scope = "REGIONAL"
}

# 2. Deploy the CloudWatch Metric Alarm Tracking WAF Aggregate Traffic Anomalies
resource "aws_cloudwatch_metric_alarm" "waf_anomaly_alarm" {
  alarm_name          = "CRITICAL-WAF-EDGE-TRAFFIC-ANOMALY-ALERT"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "AllowedRequests" # Track total allowed edge packets to catch low-and-slow spikes
  namespace           = "AWS/WAFV2"
  period              = "60" # Evaluate edge telemetry parameters every 60 seconds
  statistic           = "Sum"
  threshold           = "50000" # Trigger if traffic volume surges past 50,000 requests per minute
  alarm_description   = "Autonomous metric alarm monitoring aggregate edge saturation vectors to trigger rule overrides."

  dimensions = {
    WebACL = data.aws_wafv2_web_acl.ingress_shield.name
    Region = "us-east-1"
    Rule   = "ALL"
  }
}

# 3. Create the Secure IAM Execution Role for the Adaptive Threat Engine
resource "aws_iam_role" "adaptive_threat_role" {
  name = "DataCenter-WAF-AdaptiveThreatEngine-Role"

  uses_managed_policy_boundary = false

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege tokens enabling the function to modify the Web ACL structure
resource "aws_iam_role_policy" "adaptive_threat_privileges" {
  name = "Lambda-WAF-WebACL-Update-Privileges"
  role = aws_iam_role.adaptive_threat_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "wafv2:GetWebACL",
          "wafv2:UpdateWebACL"
        ]
        Resource = data.aws_wafv2_web_acl.ingress_shield.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}

# 4. Deploy the Serverless Adaptive Rule Tuner Script (AWS Lambda)
resource "aws_lambda_function" "adaptive_tuner_worker" {
  function_name = "Enterprise-Core-WAF-AdaptiveRuleTuner"
  role          = aws_iam_role.adaptive_threat_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "mock-adaptive-tuner.zip"
  timeout       = 30

  environment {
    variables = {
      TARGET_WAF_ARN = data.aws_wafv2_web_acl.ingress_shield.arn
      TARGET_WAF_ID  = data.aws_wafv2_web_acl.ingress_shield.id
    }
  }
}

# 5. Connect the Monitoring Alarm State Change Directly to Invoke the Lambda Tuner
resource "aws_cloudwatch_event_rule" "anomaly_trigger_rule" {
  name        = "capture-waf-metric-alarms"
  description = "Intercepts CloudWatch edge alarms indicating low-and-slow volumetric scraping attacks"

  event_pattern = jsonencode({
    "source": ["aws.cloudwatch"],
    "detail-type": ["CloudWatch Alarm State Change"],
    "detail": {
      "alarmName": [aws_cloudwatch_metric_alarm.waf_anomaly_alarm.name],
      "state": {
        "value": ["ALARM"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "bind_tuner_target" {
  rule      = aws_cloudwatch_event_rule.anomaly_trigger_rule.name
  target_id = "InvokeWAFAdaptiveRuleTuner"
  arn       = aws_lambda_function.adaptive_tuner_worker.arn
}

# Allow EventBridge to Invoke the Lambda Function Natively
resource "aws_lambda_permission" "allow_eventbridge_tuner" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.adaptive_tuner_worker.function_name
  principal     = "://amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.anomaly_trigger_rule.arn
}
