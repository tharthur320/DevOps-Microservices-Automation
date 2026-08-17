# =====================================================================
# CERTIFICATION SCENARIO 106: EVENT-DRIVEN HIGH-VELOCITY INGESTION
# COMPONENT: LAMBDA EVENT MAPPINGS POLLING PRIVATE APACHE KAFKA STREAMS
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

data "aws_subnet" "private_compute_a" {
  id = "subnet-11111111" # Isolated compute subnet hallway
}

# 2. Reference Your Central Active Amazon MSK Apache Kafka Cluster ARN
# (This represents your high-throughput messaging backbone from Phase 5)
data "aws_msk_cluster" "messaging_backbone" {
  cluster_name = "enterprise-production-core-kafka"
}

# 3. Reference Your Reusable Private Compute Function (AWS Lambda Stream Worker)
data "aws_lambda_function" "stream_consumer" {
  function_name = "Enterprise-Core-Serverless-TransactionProcessor" # Existing Scenario 60 worker role
}

# 4. Create the Secure IAM Policy Patch Allowing Lambda to Network Connect to Kafka
resource "aws_iam_role_policy" "lambda_msk_network_policy" {
  name = "Lambda-MSK-DataPlane-ExecutionPrivileges"
  role = "Pipeline-SlackNotifier-ExecutionRole" # Attaches to your existing secure VPC execution role

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kafka:DescribeCluster",
          "kafka:GetBootstrapBrokers",
          "kafka:Connect"
        ]
        Resource = data.aws_msk_cluster.messaging_backbone.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

# 5. Architect the Enterprise High-Throughput MSK-to-Lambda Event Source Mapping
resource "aws_lambda_event_source_mapping" "kafka_stream_bridge" {
  event_source_arn  = data.aws_msk_cluster.messaging_backbone.arn
  function_name     = data.aws_lambda_function.stream_consumer.arn
  enabled           = true
  starting_position = "LATEST" # Automatically ingest and process fresh incoming message deltas

  # HIGH-VOLUME INGESTION TUNING PARAMETERS
  # Pool up to 500 individual streaming records into a single array...
  batch_size        = 500 
  
  # Target Kafka Topic Name string mapping your financial logs
  topics            = ["enterprise-core-transaction-logs"] 

  depends_on = [aws_iam_role_policy.lambda_msk_network_policy]
}
