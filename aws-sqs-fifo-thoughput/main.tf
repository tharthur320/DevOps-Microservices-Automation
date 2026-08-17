# =====================================================================
# CERTIFICATION SCENARIO 114: IMMUTABLE EXACTLY-ONCE MESSAGE FABRICS
# COMPONENT: SQS FIFO QUEUES ENFORCING HIGH-THROUGHPUT SYSTEM BALANCING
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

# 1. Provision the High-Throughput Customer-Managed Master KMS Key (For SQS)
data "aws_kms_key" "sqs_crypto_key" {
  key_id = "alias/enterprise-global-core-key" # Reuses your secure Phase 3 key ciphers
}

# 2. Deploy the Hardened High-Throughput SQS FIFO Queue Subsystem
resource "aws_sqs_queue" "transaction_fifo_bus" {
  name                        = "enterprise-financial-transactions.fifo" # FIFO queues MUST terminate with the .fifo suffix
  fifo_queue                  = true
  
  # DATA PLANE ENCRYPTION PROTECTION
  kms_master_key_id          = data.aws_kms_key.sqs_crypto_key.id
  visibility_timeout_seconds  = 30
  message_retention_seconds   = 345600 # Initial baseline 4-day retention parameters
  receive_wait_time_seconds   = 20     # Enforce long-polling natively to drop API billing waste

  # 3. AUTONOMOUS DEDUPLICATION & SCALING PARAMETERS
  # Instructs AWS to calculate message body fingerprints to automatically drop duplicate events
  content_based_deduplication = true 

  # HIGH-THROUGHPUT MODE (Exceeds standard 300 transactions/sec limits)
  # Splitting deduplication scope to the message group level unlocks thousands of API operations per second
  deduplication_scope         = "messageGroup"
  fifo_throughput_limit       = "perMessageGroupId"

  tags = {
    Layer      = "High-Throughput-Message-Bus"
    SavedAsset = "True"
  }
}

# 4. Reference Your Existing Private Lambda Worker (From Scenario 112)
data "aws_lambda_function" "ingestion_worker" {
  function_name = "Enterprise-Core-OpenSearch-Ingester"
}

# 5. Bind the FIFO Queue to Your Lambda Function via Event Source Mapping
resource "aws_lambda_event_source_mapping" "fifo_event_bridge" {
  event_source_arn = aws_sqs_queue.transaction_fifo_bus.arn
  function_name    = data.aws_lambda_function.ingestion_worker.arn
  enabled          = true
  batch_size       = 10 # Process up to 10 sorted transactions per serverless execution loop
}
