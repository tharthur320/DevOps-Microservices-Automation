# =====================================================================
# CERTIFICATION SCENARIO 82: HIGH-THROUGHPUT POINT-TO-POINT STREAMING
# COMPONENT: EVENTBRIDGE PIPES COUPLING CROSS-ACCOUNT QUEUE CORRIDORS
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

# 1. Reference Your Foundational Ingestion SQS Queue (The Source Tooling Queue)
data "aws_sqs_queue" "source_tooling_queue" {
  name = "enterprise-core-transaction-queue" # Reuses your existing Scenario 60 source queue!
}

# 2. Reference the Destination SQS Queue Sitting Inside the Production Account
# (In production modules, this matches a cross-account target ARN link)
data "aws_sqs_queue" "target_production_queue" {
  name = "enterprise-production-receiver-queue"
}

# 3. Create the Secure IAM Execution Role for the Point-to-Point Pipe Engine
resource "aws_iam_role" "pipes_execution_role" {
  name = "DataCenter-EventBridge-Pipes-Runner-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege tokens enabling the pipe engine to read and write across queues
resource "aws_iam_role_policy" "pipes_least_privilege_policy" {
  name = "EventBridge-Pipes-Queue-Transit-Access"
  role = aws_iam_role.pipes_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = data.aws_sqs_queue.source_tooling_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = "arn:aws:sqs:us-east-1:888888888888:enterprise-production-receiver-queue" # Production Account ID SQS
      }
    ]
  })
}

# 4. Architect the Hardened Point-to-Point Amazon EventBridge Pipe
resource "aws_pipes_pipe" "cross_account_transit_pipe" {
  name     = "enterprise-tooling-to-production-transit-pipe"
  role_arn = aws_iam_role.pipes_execution_role.arn
  
  # SOURCE DIRECTION: Ingest messages automatically from your primary queue
  source = data.aws_sqs_queue.source_tooling_queue.arn

  # SOURCE OPTIMIZATION PARAMETERS: Tightly configures ingestion batching windows
  source_parameters {
    sqs_queue_parameters {
      batch_size                         = 10 # Pool and batch up to 10 payloads before pushing
      maximum_batching_window_in_seconds = 5  # Hold messages for up to 5 seconds max to save traffic
    }

    # INTEGRATED SOURCE FILTERING FILTER
    # Screens and drops any junk payloads right at the intake gate before transit occurs
    filter_criteria {
      filter {
        pattern = jsonencode({
          body = {
            transaction_tier = ["EnterprisePremium", "CorporateCore"]
          }
        })
      }
    }
  }

  # TARGET DIRECTION: Streams clean payloads directly across the boundary to the Production account queue
  target = "arn:aws:sqs:us-east-1:888888888888:enterprise-production-receiver-queue"

  tags = {
    Layer      = "Point-To-Point-Streaming"
    SavedAsset = "True"
  }

  depends_on = [aws_iam_role_policy.pipes_least_privilege_policy]
}
