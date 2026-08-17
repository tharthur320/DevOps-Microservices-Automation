# =====================================================================
# CERTIFICATION SCENARIO 119: ASYNCHRONOUS DATA RESILIENCE
# COMPONENT: SQS DLQ ARCHITECTURES WITH AUTOMATED CLOUDWATCH ALARM REDRIVES
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

# 1. Provision the Isolated SQS Dead-Letter Queue (The Poison Pill Container)
resource "aws_sqs_queue" "transaction_dlq" {
  name                      = "enterprise-core-transactions-dlq"
  kms_master_key_id         = "alias/aws/sqs" # Mandates data-plane encryption at rest natively
  message_retention_seconds = 1209600         # Retain toxic logs for the 14-day absolute cloud ceiling
}

# 2. Deploy the Primary Transaction Processing Ingestion SQS Queue
resource "aws_sqs_queue" "main_transaction_queue" {
  name                      = "enterprise-core-transactions-pipeline"
  kms_master_key_id         = "alias/aws/sqs"
  receive_wait_time_seconds = 20 # Forces long polling to minimize API billing waste

  # ISOLATION ENGINE LAYER: Directs un-processable records straight to the DLQ after 3 failures
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.transaction_dlq.arn
    maxReceiveCount     = 3
  })
}

# 3. Deploy the CloudWatch Metric Alarm Monitoring Dead-Letter Backlog Volume
resource "aws_cloudwatch_metric_alarm" "dlq_backlog_alarm" {
  alarm_name          = "CRITICAL-SQS-DLQ-BACKLOG-ACCUMULATION"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfMessagesVisible" # Track items trapped in the error bin
  namespace           = "AWS/SQS"
  period              = "60" # Snapshot queue metrics every 60 seconds
  statistic           = "Sum"
  threshold           = "100" # Fire the alert if more than 100 messages accumulate in the DLQ
  alarm_description   = "Triggers autonomous message recovery loops if transient errors pool inside the DLQ."

  dimensions = {
    QueueName = aws_sqs_queue.transaction_dlq.name
  }
}

# 4. Deploy the CloudWatch Event Rule Catching the Metric Breach State Change
resource "aws_cloudwatch_event_rule" "dlq_remediation_trigger" {
  name        = "trigger-autonomous-dlq-redrive"
  description = "Intercepts the DLQ alarm to instantly initiate programmatic message recycling tasks"

  event_pattern = jsonencode({
    "source": ["aws.cloudwatch"],
    "detail-type": ["CloudWatch Alarm State Change"],
    "detail": {
      "alarmName": [aws_cloudwatch_metric_alarm.dlq_backlog_alarm.name],
      "state": {
        "value": ["ALARM"]
      }
    }
  })
}

# 5. Bind the Monitoring Gate Directly to Invoke an Automated Recovery Action
resource "aws_cloudwatch_event_target" "bind_dlq_redrive" {
  rule      = aws_cloudwatch_event_rule.dlq_remediation_trigger.name
  target_id = "ExecuteSQSStartMessageMoveTask"
  arn       = "arn:aws:ssm:us-east-1:123456789012:automation-definition/AWS-StartSQSDlqRedrive" # AWS managed redrive runbook
  role_arn  = "arn:aws:iam::123456789012:role/DataCenter-EventBridge-SSM-Remediation-Role"

  # Pass parameters dynamically specifying the source error bin and target pipeline destination
  input = jsonencode({
    SourceQueueArn = aws_sqs_queue.transaction_dlq.arn
  })
}
