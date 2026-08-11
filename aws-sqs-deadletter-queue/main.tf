# =====================================================================
# CERTIFICATION SCENARIO 59: ASYNCHRONOUS FAULT-TOLERANT DECOUPLING
# COMPONENT: SQS DEAD LETTER QUEUES BREAKING POISON PILL LOOPS
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

# 1. Deploy the Isolated Dead Letter Queue (The Quarantine Vault)
resource "aws_sqs_queue" "transaction_dlq" {
  name                      = "enterprise-transaction-dlq"
  message_retention_seconds = 1209600 # Retain poison pill messages for 14 days for forensic debugging
  kms_master_key_id         = "alias/aws/sqs" # Mandates data-plane encryption at rest natively

  tags = {
    Layer      = "Messaging-Quarantine"
    SavedAsset = "True"
  }
}

# 2. Deploy the Primary Operational Ingestion SQS Transaction Queue
resource "aws_sqs_queue" "primary_transaction_queue" {
  name                      = "enterprise-core-transaction-queue"
  delay_seconds             = 0
  max_message_size          = 262144 # 256 KB standard data block payload size ceiling
  message_retention_seconds = 86400  # Retain active messages for 24 hours
  receive_wait_time_seconds = 20     # Enforce long pooling to minimize API billing waste
  kms_master_key_id         = "alias/aws/sqs"

  # REDRIVE POLICY LAYER: Automates quarantine routing for failing payloads
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.transaction_dlq.arn
    maxReceiveCount     = 3 # Isolate the message automatically after 3 failed worker attempts
  })
}

# 3. Reference Your Secure Phase 4 Active Amazon SNS Notification Alert Topic
data "aws_sns_topic" "operations_alerts" {
  name = "enterprise-infrastructure-anomaly-alerts"
}

# 4. Deploy the CloudWatch Metric Alarm Tracking Dead Letter Queue Depth
resource "aws_cloudwatch_metric_alarm" "dlq_depth_alarm" {
  alarm_name          = "CRITICAL-OPERATIONS-SQS-DEAD-LETTER-QUEUE-INGESTION"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = "60" # Snapshot queue depth metrics every 60 seconds
  statistic           = "Sum"
  threshold           = "0" # Fire the alarm instantly if even a single poison pill message drops in
  alarm_description   = "Immediate triage required: A broken or malicious payload has been quarantined inside the DLQ."

  dimensions = {
    QueueName = aws_sqs_queue.transaction_dlq.name
  }

  # ACTION TARGET MAPPING: Route the failure alert straight to your operational teams
  alarm_actions = [data.aws_sns_topic.operations_alerts.arn]
}
