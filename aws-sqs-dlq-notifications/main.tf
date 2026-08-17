# =====================================================================
# CERTIFICATION SCENARIO 129: ASYNCHRONOUS PIPELINE VISIBILITY
# COMPONENT: LAMBDA CONSUMING DLQ BREACH ALARMS FOR CHATOPS INGESTION
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

# 1. Reference Your Foundational Isolated Dead-Letter Queue (From Scenario 119)
data "aws_sqs_queue" "transaction_dlq" {
  name = "enterprise-core-transactions-dlq"
}

# 2. Deploy the CloudWatch Metric Alarm Monitoring Dead-Letter Backlog Volume
resource "aws_cloudwatch_metric_alarm" "dlq_volume_alarm" {
  alarm_name          = "CRITICAL-SQS-DLQ-MESSAGE-BACKLOG-ACCUMULATION"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfMessagesVisible" # Track items trapped in the failure container
  namespace           = "AWS/SQS"
  period              = "60" # Snapshot queue metrics every 60 seconds
  statistic           = "Sum"
  threshold           = "10" # Fire the alert if more than 10 messages pool inside the error bin
  alarm_description   = "Autonomous metric alarm monitoring dead-letter accumulation to trigger serverless ChatOps updates."

  dimensions = {
    QueueName = data.aws_sqs_queue.transaction_dlq.name
  }
}

# 3. Create the Secure IAM Execution Role for the Notification Engine
resource "aws_iam_role" "chatops_runner_role" {
  name = "DataCenter-Lambda-ChatOpsNotifier-ExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege policies enabling basic log creation and routing
resource "aws_iam_role_policy" "chatops_logging_privileges" {
  name = "Lambda-ChatOps-Logging-Access"
  role = aws_iam_role.chatops_runner_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}

# 4. Deploy the Serverless ChatOps Notification Function (AWS Lambda)
resource "aws_lambda_function" "chatops_notifier_worker" {
  id            = "Pipeline-SlackNotifier" # Linked straight to your local validation workspaces!
  function_name = "Enterprise-Core-SQS-DLQ-ChatOpsNotifier"
  role          = aws_iam_role.chatops_runner_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "mock-chatops-notifier.zip"
  timeout       = 30

  environment {
    variables = {
      SLACK_WEBHOOK_URL = "https://slack.com" # Injected via secret vars in prod
      TARGET_QUEUE_NAME = data.aws_sqs_queue.transaction_dlq.name
    }
  }
}

# 5. Connect the Monitoring Alarm State Change Directly to Invoke the Lambda Target
resource "aws_cloudwatch_event_rule" "dlq_alarm_trigger_rule" {
  name        = "capture-dlq-backlog-metric-alarms"
  description = "Intercepts CloudWatch queue alarms indicating asynchronous processing bottlenecks"

  event_pattern = jsonencode({
    "source": ["aws.cloudwatch"],
    "detail-type": ["CloudWatch Alarm State Change"],
    "detail": {
      "alarmName": [aws_cloudwatch_metric_alarm.dlq_volume_alarm.name],
      "state": {
        "value": ["ALARM"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "bind_notifier_target" {
  rule      = aws_cloudwatch_event_rule.dlq_alarm_trigger_rule.name
  target_id = "InvokeDLQChatOpsNotifier"
  arn       = aws_lambda_function.chatops_notifier_worker.arn
}

# Allow EventBridge to Invoke the Lambda Function Natively
resource "aws_lambda_permission" "allow_eventbridge_notifier" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chatops_notifier_worker.function_name
  principal     = "://amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.dlq_alarm_trigger_rule.arn
}
