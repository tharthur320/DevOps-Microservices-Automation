# =====================================================================
# CERTIFICATION SCENARIO 112: EDGE EDGE IDENTITY ACCESS GOVERNANCE
# COMPONENT: API GATEWAY CUSTOM AUTHORIZERS LOCKING DATA PORTAL PERIMETERS
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

# 1. Reference Your Foundational Public API Gateway Core Rest API
# (This links our security gatekeeper directly into your active ingress endpoints)
resource "aws_api_gateway_rest_api" "ingress_api" {
  name        = "enterprise-public-ingress-gateway"
  description = "Centralized public REST API router handling financial data plane channels"
}

# 2. Reference Your Reusable Private Compute Function (AWS Lambda Custom Token Verifier)
data "aws_lambda_function" "identity_verifier" {
  function_name = "Enterprise-Core-Serverless-TransactionProcessor" # Existing Scenario 60 worker role
}

# 3. Create the Secure IAM Execution Role Authorizing API Gateway to Invoke the Lambda
resource "aws_iam_role" "apigateway_invocation_role" {
  name = "DataCenter-APIGateway-CustomAuthorizer-InvocationRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege invocation tokens to the edge gateway role
resource "aws_iam_role_policy" "apigateway_invoke_lambda_policy" {
  name = "APIGateway-InvokeAuthorizerLambda-Access"
  role = aws_iam_role.apigateway_invocation_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = data.aws_lambda_function.identity_verifier.arn
    }]
  })
}

# 4. Architect the Hardened Edge API Gateway Custom Token Authorizer
resource "aws_api_gateway_authorizer" "jwt_edge_gatekeeper" {
  name                             = "enterprise-oauth2-jwt-authorizer"
  rest_api_id                      = aws_api_gateway_rest_api.ingress_api.id
  authorizer_uri                   = data.aws_lambda_function.identity_verifier.invoke_arn
  authorizer_credentials           = aws_iam_role.apigateway_invocation_role.arn
  
  # IDENTITY VERIFICATION PARAMETERS
  type                             = "TOKEN"
  identity_source                  = "method.request.header.Authorization" # Extract token from bearer string
  authorizer_result_ttl_in_seconds = 300 # Cache authorization results for 5 minutes to prevent lambda fatigue
}

# 5. Allow API Gateway to Invoke the Lambda Function Natively
resource "aws_lambda_permission" "allow_apigateway_invocation" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.identity_verifier.function_name
  principal     = "://amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.ingress_api.execution_arn}/authorizers/${aws_api_gateway_authorizer.jwt_edge_gatekeeper.id}"
}
