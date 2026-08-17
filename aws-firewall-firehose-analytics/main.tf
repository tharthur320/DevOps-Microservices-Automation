# =====================================================================
# CERTIFICATION SCENARIO 143: PERIMETER NETWORK THREAT INGESTION
# COMPONENT: FIREWALL ALERTS STREAMING VIA KINESIS FIREHOSE TO STORAGE
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

# 2. Provision the Highly Secured Central S3 Landing Pad Bucket Vault
resource "aws_s3_bucket" "firewall_analytics_vault" {
  bucket        = "enterprise-firewall-alert-analytics-vault-2026"
  force_destroy = false # Strict guardrail: prevents automated code deletion of compliance data
}

# 3. Create the Secure IAM Role Allowing Firehose to Write to Your S3 Vault
resource "aws_iam_role" "firehose_storage_role" {
  name = "DataCenter-KinesisFirehose-StorageStreaming-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege privileges enabling Firehose to write to the storage bucket
resource "aws_iam_role_policy" "firehose_s3_write_policy" {
  name = "Firehose-S3Bucket-Writing-Privileges"
  role = aws_iam_role.firehose_storage_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.firewall_analytics_vault.arn,
          "${aws_s3_bucket.firewall_analytics_vault.arn}/*"
        ]
      }
    ]
  })
}

# 4. Architect the Hardened Real-Time Kinesis Firehose Delivery Stream
resource "aws_kinesis_firehose_delivery_stream" "firewall_alert_delivery" {
  name        = "aws-network-firewall-alerts-delivery"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_storage_role.arn
    bucket_arn = aws_s3_bucket.firewall_analytics_vault.arn
    prefix     = "firewall-alerts/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "firewall-alerts-errors/year=!{timestamp:yyyy}/error=!{firehose:error-output-type}/"

    # BUFFERING PARAMETERS: Tunes ingestion velocity and minimizes storage request overhead
    buffer_size      = 5   # Wait until 5 Megabytes of records pool in memory...
    buffer_interval  = 60  # ...or execute bulk storage pushes every 60 seconds

    compression_format = "GZIP" # Compresses log text blocks natively to slash cloud storage bill waste
  }
}

# 5. Connect the Real-Time Infiltration Log Configuration onto the Firewall Appliance
resource "aws_networkfirewall_logging_configuration" "firewall_logs_binding" {
  firewall_arn = data.aws_networkfirewall_firewall.perimeter_shield.arn

  logging_configuration {
    log_destination_config {
      log_destination_type = "KinesisDataFirehose"
      log_type             = "ALERT" # Capture deep-packet rule drop and match violations explicitly

      log_destination = {
        deliveryStream = aws_kinesis_firehose_delivery_stream.firewall_alert_delivery.name
      }
    }
  }
}
