# =====================================================================
# CERTIFICATION SCENARIO 133: REAL-TIME NETWORK THREAT STREAMING
# COMPONENT: FIREWALL LOGS STREAMING VIA KINESIS DATA STREAMS TO LAMBDA
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

# 2. Provision the High-Speed Kinesis Stream Collecting Threat Telemetry
resource "aws_kinesis_stream" "firewall_alert_stream" {
  name             = "enterprise-network-firewall-alert-stream"
  shard_count      = 2             # Partition data lanes to absorb high-velocity mutations
  retention_period = 24            # Retain payload packets for 24 hours inside stream shards
  
  stream_mode_details {
    stream_mode = "PROVISIONED"
  }
}

# 3. Create the Secure IAM Execution Role for the Threat Parser Engine
resource "aws_iam_role" "lambda_threat_parser_role" {
  name = "DataCenter-Lambda-FirewallThreatParser-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege tokens enabling the role to read streams and manage network interfaces
resource "aws_iam_role_policy" "lambda_stream_read_policy" {
  name = "Lambda-KinesisStream-Read-Access"
  role = aws_iam_role.lambda_threat_parser_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:DescribeStream",
          "kinesis:ListShards"
        ]
        Resource = aws_kinesis_stream.firewall_alert_stream.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}

# 4. Deploy the Serverless Threat Parser Function (AWS Lambda)
resource "aws_lambda_function" "threat_parser_worker" {
  function_name = "Enterprise-Core-NetworkFirewall-ThreatParser"
  role          = aws_iam_role.lambda_threat_parser_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "mock-threat-parser.zip"
  timeout       = 30

  # Buildspec inline note: Real-time script that ingests the firewall alert JSON array,
  # extracts malicious Suricata source signatures, and pushes indicators to the SOC.
}

# 5. Bind the High-Throughput Lambda Stream Mapping Bridge
resource "aws_lambda_event_source_mapping" "threat_stream_bridge" {
  event_source_arn  = aws_kinesis_stream.firewall_alert_stream.arn
  function_name     = aws_lambda_function.threat_parser_worker.arn
  starting_position = "LATEST"
  batch_size        = 50 # Bulk-analyze 50 network drop violations per loop to flatten spikes

  depends_on = [aws_iam_role_policy.lambda_stream_read_policy]
}

# 6. Connect the Real-Time Infiltration Log Configuration onto the Firewall Appliance
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
