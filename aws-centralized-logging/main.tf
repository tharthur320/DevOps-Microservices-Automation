# =====================================================================
# CERTIFICATION SCENARIO 10: MULTI-ACCOUNT LOG RECOVERY AGGREGATION
# COMPONENT: KINESIS DATA FIREHOSE SECURING REAL-TIME METRICS DELIVERY
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Provision the Centralized Compliance Log Vault S3 Storage Bucket
resource "aws_s3_bucket" "central_log_vault" {
  bucket        = "enterprise-centralized-siem-logs-2026"
  force_destroy = true
}

# 2. Deploy a Custom AWS KMS Cryptographic Master Key for Log Encryption
resource "aws_kms_key" "log_encryption_key" {
  description             = "KMS Key forcing encryption across centralized aggregated corporate logs"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

# 3. Create the Serverless Real-Time Ingestion Buffer (Kinesis Data Firehose)
resource "aws_kinesis_firehose_delivery_stream" "log_ingestion_stream" {
  name        = "enterprise-multiaccount-log-aggregator"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_delivery_role.arn
    bucket_arn = aws_s3_bucket.central_log_vault.arn
    kms_key_arn = aws_kms_key.log_encryption_key.arn

    # OPTIMIZATION PARAMETERS: Compression and Batching rules to maximize throughput
    compression_format = "GZIP"
    buffer_size        = 5    # Wait until 5 Megabytes of logs are collected...
    buffer_interval    = 300  # ...or until 300 seconds have elapsed before writing data to S3

    prefix              = "aws-logs/year=!{timestamp:yyyy}/month=!{timestamp:MM}/"
    error_output_prefix = "aws-logs-errors/year=!{timestamp:yyyy}/error=!{firehose:error-output-type}/"
  }
}

# 4. Create the Secure Cross-Account IAM Execution Role for the Delivery Stream
resource "aws_iam_role" "firehose_delivery_role" {
  name = "DataCenter-Centralized-Log-Ingester"

  # Trust Policy: Explicitly allows other internal sub-accounts to assume this identity to stream logs
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          # Whitelists specific sub-account numbers (e.g., Application and Testing accounts)
          AWS = [
            "arn:aws:iam::111111111111:root",
            "arn:aws:iam::222222222222:root"
          ]
        }
      }
    ]
  })
}
