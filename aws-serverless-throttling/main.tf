# =====================================================================
# CERTIFICATION SCENARIO 50: SERVERLESS PERIMETER HARDENING
# COMPONENT: API GATEWAY THROTTLING CORRIDORS & LAMBDA CONCURRENCY LIMITS
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Reference Your Core Serverless REST API Endpoint Structure
resource "aws_api_gateway_rest_api" "serverless_api" {
  name        = "enterprise-core-serverless-api"
  description = "Production gateway routing traffic down to isolated microservice tiers"
}

resource "aws_api_gateway_resource" "api_resource" {
  rest_api_id = aws_api_gateway_rest_api.serverless_api.id
  parent_id   = aws_api_gateway_rest_api.serverless_api.root_resource_id
  path_part   = "transactions"
}

resource "aws_api_gateway_method" "api_method" {
  rest_api_id   = aws_api_gateway_rest_api.serverless_api.id
  resource_id   = aws_api_gateway_resource.api_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# 2. Deploy the Managed API Gateway Deployment Stage Corridor
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.serverless_api.id

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_api_gateway_method.api_method]
}

resource "aws_api_gateway_stage" "production_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.serverless_api.id
  stage_name    = "prod"
}

# 3. Enforce Strict Rate-Limiting and Burst Throttling at the Edge Layer
resource "aws_api_gateway_method_settings" "api_throttling_guardrail" {
  rest_api_id = aws_api_gateway_rest_api.serverless_api.id
  stage_name    = aws_api_gateway_stage.production_stage.stage_name
  method_path   = "*/*" # Enforces throttling globally across all resources and methods

  settings {
    metrics_enabled = true
    logging_level   = "ERROR"

    # THROTTLING CODES: Restricts throughput capacity to optimize platform load
    throttling_rate_limit  = 500  # Steady state limit: exactly 500 requests per second maximum
    throttling_burst_limit = 1000 # Burst capacity ceiling: handles up to 1,000 concurrent request bursts
  }
}

# 4. Deploy the Hardened Serverless Lambda Function with Fixed Concurrency Boundaries
resource "aws_lambda_function" "transaction_processor" {
  function_name = "Enterprise-Core-Serverless-TransactionProcessor"
  role          = "arn:aws:iam::123456789012:role/MockLambdaRole"
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "mock-lambda-payload.zip"

  # ZERO-TRUST COMPUTE BOUNDARY: Isolates execution capacity to shield external systems
  reserved_concurrent_executions = 50 # Locks this function to a max of 50 concurrent task instances

  tags = {
    Layer      = "Serverless-Compute-Tier"
    SavedAsset = "True"
  }
}
