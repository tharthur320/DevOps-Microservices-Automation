# =====================================================================
# CERTIFICATION SCENARIO 90: MESSAGE RESILIENCE & BACKLOG DECOUPLING
# COMPONENT: EVENTBRIDGE ALARMS SCALING SQS MESSAGE RETENTION LIFECYCLES
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

# 1. Deploy the Primary Decoupled Operational Transaction Queue
resource "aws_sqs_queue" "resilient_transaction_queue" {
  name                      = "enterprise-dynamic-retention-queue"
  kms_master_key_id         = "alias/aws/sqs" # Mandates data-plane encryption at rest natively
  receive_wait_time_seconds = 20              # Enable long pooling to minimize API billing waste

  # INITIAL STATE: Default baseline 4-day message retention window parameters (345,600 seconds)
  message_retention_seconds = 345600 
}

# 2. Deploy the CloudWatch Metric Alarm Monitoring Backlog Volume Depth
resource "aws_cloudwatch_metric_alarm" "backlog_volume_alarm" {
  alarm_name          = "CRITICAL-SQS-TRANSACTION-BACKLOG-SPIKE"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfMessagesVisible" # Native SQS backlog tracking metric
  namespace           = "AWS/SQS"
  period              = "60" # Snapshot queue depth metrics every 60 seconds
  statistic           = "Sum"
  threshold           = "10000" # Fire the alert if more than 10,000 transactions stack up un-processed
  alarm_description   = "Triggers real-time queue preservation actions if downstream workers drop efficiency keys."

  dimensions = {
    QueueName = aws_sqs_queue.resilient_transaction_queue.name
  }
}

# 3. Create the Secure IAM Execution Role for the Queue Auto-Scaler Engine
resource "aws_iam_role" "queue_lifecycle_role" {
  name = "DataCenter-SQS-Lifecycle-ExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege attribute modification tokens to the role
resource "aws_iam_role_policy" "queue_lifecycle_privileges" {
  name = "Lambda-SQS-SetAttributes-Privileges"
  role = aws_iam_role.queue_lifecycle_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SetQueueAttributes",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.resilient_transaction_queue.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}

# 4. Deploy the Serverless Queue Lifecycle Modification Script (AWS Lambda)
resource "aws_lambda_function" "queue_lifecycle_worker" {
  function_name = "Enterprise-Core-SQS-RetentionExtender"
  role          = aws_iam_role.queue_lifecycle_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "mock-queue-extender.zip"
  timeout       = 30

  environment {
    variables = {
      TARGET_QUEUE_URL = aws_sqs_queue.resilient_transaction_queue.url
    }
  }
}

# 5. Connect the Event Bus Directly to Invoke the Lambda Lifecycle Target
resource "aws_cloudwatch_event_rule" "backlog_trigger_rule" {
  name        = "capture-sqs-backlog-failures"
  description = "Intercepts CloudWatch metrics indicating un-processed transaction spikes"

  event_pattern = jsonencode({
    "source": ["aws.cloudwatch"],
    "detail-type": ["CloudWatch Alarm State Change"],
    "detail": {
      "alarmName": [aws_cloudwatch_metric_alarm.backlog_volume_alarm.name],
      "state": {
        "value": ["ALARM"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "bind_lifecycle_target" {
  rule      = aws_cloudwatch_event_rule.backlog_trigger_rule.name
  target_id = "InvokeQueueLifecycleExtender"
  arn       = aws_lambda_function.queue_lifecycle_worker.arn
}

# Allow EventBridge to Invoke the Lambda Function Natively
resource "aws_lambda_permission" "allow_eventbridge_lifecycle" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.queue_lifecycle_worker.function_name
  principal     = "://amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.backlog_trigger_rule.arn
}
