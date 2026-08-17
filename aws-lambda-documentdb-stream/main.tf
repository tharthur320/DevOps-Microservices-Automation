# =====================================================================
# CERTIFICATION SCENARIO 149: HIGH-VELOCITY DOCUMENT STREAM INGESTION
# COMPONENT: LAMBDA EVENT MAPPINGS POLLING PRIVATE DOCUMENTDB STREAMS
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

# 1. Reference Your Foundational Private Data Center VPC Network
data "aws_vpc" "datacenter_vpc" {
  id = "vpc-00000000000000000"
}

# 2. Reference Your Central Active Amazon DocumentDB Cluster ARN
# (This represents your high-throughput document database backbone)
data "aws_docdb_cluster" "document_backbone" {
  cluster_identifier = "enterprise-production-core-docdb"
}

# 3. Reference Your Reusable Private Compute Function (AWS Lambda Stream Worker)
data "aws_lambda_function" "stream_processor" {
  function_name = "Enterprise-Core-Serverless-TransactionProcessor" # Existing Scenario 60 worker role
}

# 4. Create the Secure IAM Policy Patch Allowing Lambda to Read DocumentDB Streams
resource "aws_iam_role_policy" "lambda_docdb_datacenter_policy" {
  name = "Lambda-DocDB-ChangeStream-ExecutionPrivileges"
  role = "Pipeline-SlackNotifier-ExecutionRole" # Attaches to your existing secure VPC execution role

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBClusters",
          "rds:Connect"
        ]
        Resource = data.aws_docdb_cluster.document_backbone.arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue" # Allowing access to database cluster credential secrets tokens
        ]
        Resource = "arn:aws:secretsmanager:us-east-1:123456789012:secret:docdb-admin-credentials-*"
      }
    ]
  })
}

# 5. Architect the Enterprise High-Throughput DocumentDB-to-Lambda Event Source Mapping
resource "aws_lambda_event_source_mapping" "docdb_stream_bridge" {
  event_source_arn  = data.aws_docdb_cluster.document_backbone.arn
  function_name     = data.aws_lambda_function.stream_processor.arn
  enabled           = true
  starting_position = "LATEST" # Automatically ingest and process fresh database mutations

  # HIGH-VOLUME STREAM TUNING PARAMETERS
  # Pool up to 100 individual document changes into a single array...
  batch_size        = 100 
  
  # Configure database-specific properties securely
  document_db_event_source_config {
    database_name   = "enterprise_commerce"
    collection_name = "client_transactions"
  }

  source_access_configuration {
    type = "BASIC_AUTH"
    uri  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:docdb-admin-credentials-abcde" # Credentials secret token
  }

  depends_on = [aws_iam_role_policy.lambda_docdb_datacenter_policy]
}
