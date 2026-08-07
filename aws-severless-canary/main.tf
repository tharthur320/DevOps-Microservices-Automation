# =====================================================================
# CERTIFICATION SCENARIO 7: SERVERLESS CANARY TRAFFIC RESILIENCE
# COMPONENT: AWS CODEDEPLOY FOR SAFE STEP-BY-STEP LAMBDA DEPLOYMENTS
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Provision the Target Serverless Deployment Application Model
resource "aws_codedeploy_app" "serverless_app" {
  compute_platform = "Lambda" # Mandates the serverless execution layer engine
  name             = "enterprise-transaction-router"
}

# 2. Deploy a Pre-emptive CloudWatch Alarm Monitoring Application Runtime Faults
resource "aws_cloudwatch_metric_alarm" "lambda_error_alarm" {
  alarm_name          = "Production-Lambda-Runtime-Errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0" # Fires instantly if even a single error occurs on the system
  alarm_description   = "Rollback trigger tracking any active software crash anomalies."

  dimensions = {
    FunctionName = "enterprise-core-router"
  }
}

# 3. Architect the Serverless Canary Deployment Group Controller
resource "aws_codedeploy_deployment_group" "lambda_canary_group" {
  app_name              = aws_codedeploy_app.serverless_app.name
  deployment_group_name = "serverless-canary-release-channel"
  service_role_arn      = "arn:aws:iam::123456789012:role/MockCodeDeployRole"

  # NATIVE CANARY ROUTER: Executes automatic 10% traffic routing over a 10-minute window
  deployment_config_name = "CodeDeployDefault.LambdaCanary10Percent10Minutes"

  # Fail-Safe Protection Safeguard: Binds deployment steps straight to your runtime alert monitors
  alarm_configuration {
    alarms   = [aws_cloudwatch_metric_alarm.lambda_error_alarm.name]
    enabled  = true
    ignore_poll_alarm_failure = false
  }

  # Auto-Rollback Options: Enforce automatic reversion if any deployment step errors occur
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }
}
