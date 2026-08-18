# =====================================================================
# CERTIFICATION SCENARIO 193: REAL-TIME NETWORK THREAT STREAMING
# COMPONENT: FIREWALL LOGS DRIVING AUTOMATED COMPUTE TARGET EVICTIONS
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
resource "aws_kinesis_stream" "firewall_alert_stream_v3" {
  name             = "enterprise-network-firewall-alert-stream-v3"
  shard_count      = 2             # Partition data lanes to absorb high-velocity mutations
  retention_period = 24            # Retain payload packets for 24 hours inside stream shards
  
  stream_mode_details {
    stream_mode = "PROVISIONED"
  }
}

# 3. Create the Secure IAM Execution Role for the Threat Eviction Engine
resource "aws_iam_role" "lambda_eviction_role" {
  name = "DataCenter-Lambda-FirewallThreatEviction-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege tokens enabling the role to deregister load-balancer targets
resource "aws_iam_role_policy" "lambda_eviction_policy" {
  name = "Lambda-KinesisStream-TargetDeregistration-Access"
  role = aws_iam_role.lambda_eviction_role.id

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
        Resource = aws_kinesis_stream.firewall_alert_stream_v3.arn
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:DescribeTargetHealth"
        ]
        Resource = "*" # Applied across corporate load balancers to isolate compromised nodes
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}

# 4. Deploy the Serverless Threat Eviction Function (AWS Lambda)
resource "aws_lambda_function" "threat_eviction_worker" {
  function_name = "Enterprise-Core-NetworkFirewall-ThreatEviction"
  role          = aws_iam_role.lambda_eviction_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "mock-threat-evvalidator.zip"
  timeout       = 30

  # Buildspec inline note: Real-time script that ingests the firewall alert JSON array,
  # extracts compromised local instance IDs, and immediately severs target group bindings.
}

# 5. Bind the High-Throughput Lambda Stream Mapping Bridge
resource "aws_lambda_event_source_mapping" "threat_eviction_bridge" {
  event_source_arn  = aws_kinesis_stream.firewall_alert_stream_v3.arn
  function_name     = aws_lambda_function.threat_eviction_worker.arn
  starting_position = "LATEST"
  batch_size        = 50 # Bulk-analyze 50 network drop violations per loop to flatten spikes

  depends_on = [aws_iam_role_policy.lambda_eviction_policy]
}

# 6. Connect the Real-Time Infiltration Log Configuration onto the Firewall Appliance
resource "aws_networkfirewall_logging_configuration" "firewall_logs_binding" {
  firewall_arn = data.aws_networkfirewall_firewall.perimeter_shield.arn

  logging_configuration {
    log_destination_config {
      log_destination_type = "KinesisDataStream"
      log_type             = "ALERT" # Capture deep-packet rule drop and match violations explicitly

      log_destination = {
        deliveryStream = aws_kinesis_stream.firewall_alert_stream_v3.name
      }
    }
  }
}
