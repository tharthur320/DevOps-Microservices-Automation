# =====================================================================
# CERTIFICATION SCENARIO 163: REAL-TIME NETWORK THREAT STREAMING
# COMPONENT: FIREWALL LOGS COUPLING SHARD SEGMENTS WITH FAULT-TOLERANT DLQS
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

# 2. Provision the Isolated SQS Dead-Letter Queue (The Stream Poison Pill Container)
resource "aws_sqs_queue" "stream_poison_pill_dlq" {
  name                      = "enterprise-network-threatstream-dlq"
  kms_master_key_id         = "alias/aws/sqs" # Mandates data-plane encryption at rest natively
  message_retention_seconds = 1209600         # Retain toxic logs for the 14-day absolute cloud ceiling
}

# 3. Provision the High-Speed Kinesis Stream Collecting Threat Telemetry
resource "aws_kinesis_stream" "firewall_alert_stream" {
  name             = "enterprise-network-firewall-alert-stream-v2"
  shard_count      = 2             # Partition data lanes to absorb high-velocity mutations
  retention_period = 24            # Retain payload packets for 24 hours inside stream shards
  
  stream_mode_details {
    stream_mode = "PROVISIONED"
  }
}

# 4. Reference Your Reusable Private Compute Function (AWS Lambda Threat Worker)
data "aws_lambda_function" "threat_parser_worker" {
  function_name = "Enterprise-Core-NetworkFirewall-ThreatParser" # Existing Scenario 133 worker role
}

# 5. Create the Secure IAM Policy Patch Allowing Lambda to Route Stream Failures to SQS
resource "aws_iam_role_policy" "lambda_stream_dlq_policy" {
  name = "Lambda-KinesisStream-DLQ-RoutingAccess"
  role = "DataCenter-Lambda-FirewallThreatParser-Role" # Attaches to your existing Scenario 133 parser role

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.stream_poison_pill_dlq.arn
      }
    ]
  })
}

# 6. Architect the Enterprise High-Throughput Lambda Stream Mapping with DLQ Targets
resource "aws_lambda_event_source_mapping" "threat_stream_dlq_bridge" {
  event_source_arn  = aws_kinesis_stream.firewall_alert_stream.arn
  function_name     = data.aws_lambda_function.threat_parser_worker.arn
  starting_position = "LATEST"
  batch_size        = 50 # Bulk-analyze 50 network drop violations per loop to flatten spikes

  # SELF-HEALING & CIRCUIT BREAKER TUNING PARAMETERS
  bisect_batch_on_function_error = true # Split a failing batch in half recursively to isolate poison pills
  maximum_retry_attempts         = 2    # Retry failed sub-batches twice before dropping

  # AUTOMATED FAILURE DESTINATION TARGET
  destination_config {
    on_failure {
      destination_arn = aws_sqs_queue.stream_poison_pill_dlq.arn
    }
  }

  depends_on = [aws_iam_role_policy.lambda_stream_dlq_policy]
}

# 7. Connect the Real-Time Infiltration Log Configuration onto the Firewall Appliance
resource "aws_networkfirewall_logging_configuration" "firewall_logs_binding" {
  firewall_arn = data.aws_networkfirewall_firewall.perimeter_shield.arn

  logging_configuration {
    log_destination_config {
      log_destination_type = "KinesisDataStream"
      log_type             = "ALERT" # Capture deep-packet rule drop and match violations explicitly

      log_destination = {
        deliveryStream = aws_kinesis_stream.firewall_alert_stream.name
      }
    }
  }
}
