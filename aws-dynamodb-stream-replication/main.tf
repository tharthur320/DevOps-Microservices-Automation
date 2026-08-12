# =====================================================================
# CERTIFICATION SCENARIO 73: DYNAMIC REAL-TIME REPLICATION MESHES
# COMPONENT: DYNAMODB STREAMS COUPLING MULTI-REGION DATA TIERS
# =====================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Primary Region Provider block (Virginia Hub)
provider "aws" {
  region = "us-east-1"
}

# Secondary Region Provider block (Oregon Disaster Recovery Hub)
provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

# 1. Deploy the Primary Transaction Ledger Table with Streams Activated (Virginia)
resource "aws_dynamodb_table" "primary_ledger" {
  name             = "enterprise-production-transaction-ledger"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "TransactionID"

  attribute {
    name = "TransactionID"
    type = "S"
  }

  # CRITICAL TELEMETRY POSTURE: Enables the real-time mutation tracking bus
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES" # Captures both the data state before and after the write

  tags = {
    Layer      = "Database-Primary-Tier"
    SavedAsset = "True"
  }
}

# 2. Deploy the Identical Destination Backup Table in the Secondary Region (Oregon)
resource "aws_dynamodb_table" "backup_ledger" {
  provider     = aws.west # Forces this module block to build inside us-west-2
  name         = "enterprise-dr-transaction-ledger-backup"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "TransactionID"

  attribute {
    name = "TransactionID"
    type = "S"
  }

  tags = {
    Layer      = "Database-Disaster-Recovery-Tier"
    SavedAsset = "True"
  }
}

# 3. Reference Your Reusable Private Compute Function (AWS Lambda Sync Writer)
data "aws_lambda_function" "replication_worker" {
  function_name = "Enterprise-Core-Serverless-TransactionProcessor" # Existing Scenario 60 worker
}

# 4. Architect the High-Throughput DynamoDB Stream Ingestion Mapping Bridge
resource "aws_lambda_event_source_mapping" "stream_bridge" {
  event_source_arn  = aws_dynamodb_table.primary_ledger.stream_arn
  function_name     = data.aws_lambda_function.replication_worker.arn
  starting_position = "LATEST" # Automatically ingest and process fresh incoming table mutations

  # STREAM BATCHING CONTROLS: Optimizes computational efficiency
  batch_size                         = 50 # Process up to 50 row modifications simultaneously
  maximum_batching_window_in_seconds = 5  # Pool database mutations for up to 5 seconds max

  # Fail-Safe Circuit Breaker: Safely split and isolate corrupt batch payloads
  bisect_batch_on_function_error = true
  maximum_retry_attempts         = 3
}
