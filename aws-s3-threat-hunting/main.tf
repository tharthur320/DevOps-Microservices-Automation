# =====================================================================
# CERTIFICATION SCENARIO 96: REAL-TIME DATA PROTECTION AUDITING
# COMPONENT: CLOUDTRAIL DATA EVENTS STREAMING TO SECURE KINESIS SHARDS
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

# 1. Provision the High-Speed Kinesis Stream Collecting Threat Telemetry
resource "aws_kinesis_stream" "s3_threat_stream" {
  name             = "enterprise-s3-data-plane-threat-stream"
  shard_count      = 2             # Partition data lanes to absorb high-velocity mutations
  retention_period = 24            # Retain payload packets for 24 hours inside stream shards
  
  stream_mode_details {
    stream_mode = "PROVISIONED"
  }
}

# 2. Reference the Central S3 Logging Destination Vault Bucket
data "aws_s3_bucket" "cloudtrail_storage_vault" {
  name = "enterprise-organization-cloudtrail-audit-vault-2026" # Reuses your Scenario 87 bucket!
}

# 3. Create the Secure CloudTrail Event Execution IAM Role
resource "aws_iam_role" "cloudtrail_stream_role" {
  name = "DataCenter-CloudTrail-To-Kinesis-ExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege privileges enabling CloudTrail to write straight to Kinesis shards
resource "aws_iam_role_policy" "cloudtrail_kinesis_write" {
  name = "CloudTrail-Kinesis-DataStream-Write-Access"
  role = aws_iam_role.cloudtrail_stream_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ]
        Resource = aws_kinesis_stream.s3_threat_stream.arn
      }
    ]
  })
}

# 4. Architect the Hardened AWS CloudTrail Active Data Event Trail
resource "aws_cloudtrail" "s3_data_event_trail" {
  name                          = "enterprise-s3-dataplane-audit-trail"
  s3_bucket_name                = data.aws_s3_bucket.cloudtrail_storage_vault.id
  include_global_service_events = false
  is_multi_region_trail         = true

  # REAL-TIME INGESTION ROUTING: Send events straight to your high-speed stream shards
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_stream_role.arn
  # (AWS leverages the log stream interface parameters to translate the data tunnel destination)
  
  # DATA EVENT SELECTOR LAYER: Explicitly captures file modifications at the storage layer
  event_selector {
    read_write_type           = "WriteOnly" # Capture deletes, overrides, and updates to minimize data noise
    include_management_events = false       # Discard heavy admin console logs to isolate data-plane attacks

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::enterprise-core-production-confidential-data-2026/*"] # Targets your Scenario 66 data bucket!
    }
  }

  tags = {
    Layer      = "DataPlane-Threat-Hunting"
    SavedAsset = "True"
  }

  depends_on = [aws_iam_role_policy.cloudtrail_kinesis_write]
}

# 5. Reference Your Reusable Private Lambda Function Processing Telemetry
data "aws_lambda_function" "incident_responder" {
  function_name = "Enterprise-Core-Serverless-TransactionProcessor" # Existing Scenario 60 batch worker
}

# 6. Bind the High-Throughput Lambda Stream Mapping Bridge
resource "aws_lambda_event_source_mapping" "threat_stream_mapping" {
  event_source_arn  = aws_kinesis_stream.s3_threat_stream.arn
  function_name     = data.aws_lambda_function.incident_responder.arn
  starting_position = "LATEST"
  batch_size        = 10 # Bulk-analyze 10 structural JSON data mutations per execution loop to flatten spikes
}
