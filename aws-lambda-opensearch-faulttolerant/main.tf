# =====================================================================
# CERTIFICATION SCENARIO 139: HIGH-VELOCITY ANALYTICS LOG INGESTION
# COMPONENT: LAMBDA EVENT SOURCE MAPPING DRIVING FAULT-TOLERANT OPENSEARCH INDEXING
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

# 1. Reference Your Existing Private Network Search Cluster (From Scenario 31)
data "aws_opensearch_domain" "security_analytics_cluster" {
  domain_name = "enterprise-security-analytics"
}

# 2. Reference Your Existing High-Volume Log Queue (From Scenario 119)
data "aws_sqs_queue" "log_ingest_queue" {
  name = "enterprise-core-transactions-pipeline"
}

# 3. Create the Secure IAM Execution Role with VPC and OpenSearch Capabilities
resource "aws_iam_role" "lambda_opensearch_ingest_role" {
  name = "DataCenter-Lambda-OpenSearchIngestFaultTolerant-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Attach native policies allowing the worker to mount network interfaces and talk to OpenSearch
resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.lambda_opensearch_ingest_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Bind an explicit policy granting data-plane write access to the specific OpenSearch domain
resource "aws_iam_role_policy" "opensearch_write_access" {
  name = "Lambda-OpenSearch-DataPlane-Access"
  role = aws_iam_role.lambda_opensearch_ingest_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "es:ESHttpGet",
          "es:ESHttpPost",
          "es:ESHttpPut"
        ]
        Resource = "${data.aws_opensearch_domain.security_analytics_cluster.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = data.aws_sqs_queue.log_ingest_queue.arn
      }
    ]
  })
}

# 4. Deploy the Hardened Lambda Ingestion Processor with Private Network Routing
resource "aws_lambda_function" "opensearch_ingester" {
  function_name = "Enterprise-Core-OpenSearch-FaultTolerantIngester"
  role          = aws_iam_role.lambda_opensearch_ingest_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "mock-opensearch-ingester.zip"
  
  timeout       = 60 # Extended 60-second execution safety window to absorb bulk request processing delays
  memory_size   = 512 # Allocated memory blocks to optimize JSON indexing buffers

  # PRIVATE NETWORK CONTAINMENT: Force the function to sit inside the isolated search subnets
  vpc_config {
    subnet_ids         = ["subnet-11111111"] # Isolated search subnet hallways (Scenario 31)
    security_group_ids = ["sg-00000000000000000"]
  }

  environment {
    variables = {
      OPENSEARCH_ENDPOINT = "https://${data.aws_opensearch_domain.security_analytics_cluster.endpoint}"
    }
  }
}

# 5. Architect the Fault-Tolerant Lambda Event Source Mapping Bridge
resource "aws_lambda_event_source_mapping" "search_stream_mapping" {
  event_source_arn  = data.aws_sqs_queue.log_ingest_queue.arn
  function_name     = aws_lambda_function.opensearch_ingester.arn
  enabled           = true

  batch_size                         = 20 # Bulk-inject up to 20 log records per execution loop
  maximum_batching_window_in_seconds = 5  # Pool entries for 5 seconds to maximize indexing throughput

  # PARTIAL BATCH FAILURES ENFORCEMENT: Safely isolates dropped entries at the message level
  function_response_types = ["ReportBatchItemFailures"]

  depends_on = [aws_iam_role_policy.opensearch_write_access]
}
