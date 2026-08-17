# =====================================================================
# CERTIFICATION SCENARIO 159: HIGH-VELOCITY LEDGER STREAM INGESTION
# COMPONENT: LAMBDA EVENT MAPPINGS POLLING PRIVATE DYNAMODB STREAMS
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

# 1. Reference Your Central Active Amazon DynamoDB Ledger Table
# (Enforces native, kernel-level image logging for all table mutations)
resource "aws_dynamodb_table" "transaction_ledger" {
  name             = "enterprise-core-financial-ledger"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "TransactionID"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES" # Capture before-and-after states for explicit audit trails

  attribute {
    name = "TransactionID"
    type = "S"
  }

  tags = {
    Layer      = "Database-Ledger-Tier"
    Compliance = "RealTime-Audit-Enabled"
  }
}

# 2. Reference Your Reusable Private Compute Function (AWS Lambda Stream Worker)
data "aws_lambda_function" "stream_auditor" {
  function_name = "Enterprise-Core-Serverless-TransactionProcessor" # Existing Scenario 60 worker role
}

# 3. Create the Secure IAM Policy Patch Allowing Lambda to Consume DynamoDB Streams
resource "aws_iam_role_policy" "lambda_dynamodb_stream_policy" {
  name = "Lambda-DynamoDB-ChangeStream-ExecutionPrivileges"
  role = "Pipeline-SlackNotifier-ExecutionRole" # Attaches to your existing secure VPC execution role

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:DescribeStream",
          "dynamodb:ListStreams"
        ]
        Resource = aws_dynamodb_table.transaction_ledger.stream_arn
      }
    ]
  })
}

# 4. Architect the Enterprise High-Throughput DynamoDB-to-Lambda Event Source Mapping
resource "aws_lambda_event_source_mapping" "dynamodb_stream_bridge" {
  event_source_arn  = aws_dynamodb_table.transaction_ledger.stream_arn
  function_name     = data.aws_lambda_function.stream_auditor.arn
  enabled           = true
  starting_position = "LATEST" # Automatically ingest and process fresh table mutations

  # HIGH-VOLUME STREAM TUNING & FAULT-TOLERANCE PARAMETERS
  batch_size                         = 100 # Pool up to 100 individual document changes into a single array
  maximum_batching_window_in_seconds = 5   # Hold messages for up to 5 seconds max to maximize indexing throughput
  
  # SELF-HEALING CIRCUIT BREAKER
  # If a single message causes a processing failure, split the batch in half recursively to isolate the broken item
  bisect_batch_on_function_error     = true 
  maximum_retry_attempts             = 3    # Retry failed sub-batches 3 times before routing to DLQ

  depends_on = [aws_iam_role_policy.lambda_dynamodb_stream_policy]
}
