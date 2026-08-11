# =====================================================================
# CERTIFICATION SCENARIO 62: MESSAGING HEALING & GOVERNANCE PIPELINES
# COMPONENT: STEP FUNCTIONS ASL RUNNERS HANDLING AUTOMATED DLQ REDRIVES
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

# 1. Reference Your Existing Scenario 59 Active SQS Queue Infrastructure ARNs
data "aws_sqs_queue" "primary_queue" {
  name = "enterprise-core-transaction-queue"
}

data "aws_sqs_queue" "quarantine_dlq" {
  name = "enterprise-transaction-dlq"
}

# 2. Architect the Automated Message Redrive Step Functions State Machine
resource "aws_sfn_state_machine" "dlq_redrive_engine" {
  name     = "enterprise-sqs-dlq-automated-redriver"
  role_arn = aws_iam_role.step_functions_redrive_role.arn

  # AMAZON STATES LANGUAGE (ASL): Native service integrations driving automated SQS looping
  definition = jsonencode({
    Comment = "Orchestration state machine reading, checking, and re-injecting messages out of DLQ"
    StartAt = "ReceiveFromDLQ"
    States = {
      ReceiveFromDLQ = {
        Type     = "Task"
        Resource = "arn:aws:states:::sqs:receiveMessage"
        Parameters = {
          QueueUrl            = data.aws_sqs_queue.quarantine_dlq.url
          MaxNumberOfMessages = 1
          WaitTimeSeconds     = 5
        }
        ResultPath = "$.DLQResponse"
        Next       = "CheckIfMessageExists"
      }
      CheckIfMessageExists = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.DLQResponse.Messages"
            IsPresent     = true
            Next          = "ReinjectToPrimaryQueue"
          }
        ]
        Default = "ExecutionComplete"
      }
      ReinjectToPrimaryQueue = {
        Type     = "Task"
        Resource = "arn:aws:states:::sqs:sendMessage"
        Parameters = {
          QueueUrl    = data.aws_sqs_queue.primary_queue.url
          MessageBody = "$.DLQResponse.Messages.Body"
        }
        ResultPath = "$.SendResponse"
        Next       = "DeleteFromDLQ"
      }
      DeleteFromDLQ = {
        Type     = "Task"
        Resource = "arn:aws:states:::sqs:deleteMessage"
        Parameters = {
          QueueUrl      = data.aws_sqs_queue.quarantine_dlq.url
          ReceiptHandle = "$.DLQResponse.Messages.ReceiptHandle"
        }
        ResultPath = "$.DeleteResponse"
        Next       = "ReceiveFromDLQ" # Looping mechanism to process trailing items in the queue
      }
      ExecutionComplete = {
        Type = "Succeed"
      }
    }
  })

  tags = {
    Layer      = "Self-Healing-Workflow"
    SavedAsset = "True"
  }
}

# 3. Create the Secure IAM Execution Role for the Redrive Automation Engine
resource "aws_iam_role" "step_functions_redrive_role" {
  name = "DataCenter-StepFunctions-DLQ-Redriver-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege queue read, write, and delete tokens to the role
resource "aws_iam_role_policy" "tgw_redrive_policy" {
  name = "StepFunctions-SQS-Redrive-Privileges"
  role = aws_iam_role.step_functions_redrive_role.id

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
        Resource = data.aws_sqs_queue.quarantine_dlq.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = data.aws_sqs_queue.primary_queue.arn
      }
    ]
  })
}
