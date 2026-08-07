# =====================================================================
# CERTIFICATION SCENARIO 32: DISTRIBUTED MICROSERVICES ORCHESTRATION
# COMPONENT: STEP FUNCTIONS STATE MACHINES WITH INTEGRATED RETRY CODES
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Architect the Declarative Distributed Step Functions State Machine
resource "aws_sfn_state_machine" "order_orchestrator" {
  name     = "enterprise-order-processing-orchestrator"
  role_arn = aws_iam_role.step_functions_execution_role.arn

  # AMAZON STATES LANGUAGE (ASL): Declares the state machine's logical steps and fallback retries
  definition = jsonencode({
    Comment = "Orchestration engine managing multi-step transactional checkout microservices"
    StartAt = "ProcessPayment"
    States = {
      ProcessPayment = {
        Type     = "Task"
        Resource = "arn:aws:lambda:us-east-1:123456789012:function:ProcessPaymentFunction"
        
        # EXPERENTIAL BACKOFF RETRY CONTROLS: Self-heals from temporary network blips
        Retry = [{
          ErrorEquals     = ["States.ALL"]
          IntervalSeconds = 2   # Wait 2 seconds before the first retry attempt
          MaxAttempts     = 3   # Stop attempting after 3 consecutive failures
          BackoffRate     = 2.0 # Mathematically doubles the wait time on each retry (2s -> 4s -> 8s)
        }]
        
        Next = "VerifyInventory"
      }
      VerifyInventory = {
        Type     = "Task"
        Resource = "arn:aws:lambda:us-east-1:123456789012:function:VerifyInventoryFunction"
        End      = true
      }
    }
  })

  tags = {
    Layer      = "Workflow-Orchestration"
    SavedAsset = "True"
  }
}

# 2. Deploy a Secure Private API Gateway to Trigger the Workflow Internally
resource "aws_api_gateway_rest_api" "private_api" {
  name        = "Internal-Workflow-Trigger-API"
  description = "Private routing endpoint exposed exclusively within core networks"
  
  endpoint_configuration {
    types = ["PRIVATE"] # Strict Zero-Trust Posture: The endpoint is invisible to the public web
  }
}

# 3. Create the Secure IAM Execution Role for the State Machine Framework
resource "aws_iam_role" "step_functions_execution_role" {
  name = "DataCenter-StepFunctions-Orchestrator-Runner"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Grant the state machine role permissions to invoke downstream backend Lambda tasks
resource "aws_iam_role_policy" "step_functions_lambda_access" {
  name = "StepFunctions-Lambda-Execution-Privileges"
  role = aws_iam_role.step_functions_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = "*"
    }]
  })
}
