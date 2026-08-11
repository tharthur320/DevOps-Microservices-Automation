# =====================================================================
# CERTIFICATION SCENARIO 60: SERVERLESS BULK STREAM INGESTION
# COMPONENT: LAMBDA EVENT SOURCE MAPPINGS BATCHING QUEUE PAYLOADS
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

# 1. Reference Your Existing High-Volume Ingestion SQS Queue
# (This links our batching engine directly to your Phase 5 SQS infrastructure assets)
data "aws_sqs_queue" "incoming_queue" {
  name = "enterprise-core-transaction-queue"
}

# 2. Reference Your Reusable Private Compute Function (AWS Lambda)
data "aws_lambda_function" "processor_lambda" {
  function_name = "Enterprise-Core-Serverless-TransactionProcessor"
}

# 3. Create the Secure IAM Policy Allowing Lambda to Read and Delete SQS Messages
resource "aws_iam_role_policy" "lambda_sqs_read_policy" {
  name = "Lambda-SQS-EventSource-ExecutionPrivileges"
  role = "Pipeline-SlackNotifier-ExecutionRole" # Attaches to your existing secure execution role

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]
      Resource = data.aws_sqs_queue.incoming_queue.arn
    }]
  })
}

# 4. Architect the High-Throughput Lambda Event Source Mapping Subsystem
resource "aws_lambda_event_source_mapping" "queue_batch_aggregator" {
  event_source_arn = data.aws_sqs_queue.incoming_queue.arn
  function_name    = data.aws_lambda_function.processor_lambda.arn
  enabled          = true

  # COMPUTE PROCESSING EFFICIENCY PARAMETERS
  # Wait until 100 messages accumulate...
  batch_size                         = 100 
  # ...or wait up to 10 seconds max before packaging data arrays into the Lambda invocation
  maximum_batching_window_in_seconds = 10  

  # Fail-Safe Split Routing: Handles partial batch failures gracefully
  function_response_types = ["ReportBatchItemFailures"] # Returns specific un-processable IDs to the queue

  depends_on = [aws_iam_role_policy.lambda_sqs_read_policy]
}
