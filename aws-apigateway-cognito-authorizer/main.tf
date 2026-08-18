# =====================================================================
# CERTIFICATION SCENARIO 182: ZERO-TRUST EDGE IDENTITY ACCESS
# COMPONENT: API GATEWAY COGNITO AUTHORIZERS LOCKING INBOUND USER RUNTIMES
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

# 1. Reference Your Foundational Public API Gateway Ingress (From Scenario 112)
data "aws_api_gateway_rest_api" "ingress_gateway" {
  name = "enterprise-public-ingress-gateway"
}

# 2. Provision the Central Secure Cognito User Pool Identity Directory
resource "aws_cognito_user_pool" "client_directory" {
  name                     = "enterprise-client-identity-pool"
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  tags = {
    Layer      = "Identity-Directory-Core"
    SavedAsset = "True"
  }
}

# 3. Deploy the Cognito User Pool Client Application Token Envelope
resource "aws_cognito_user_pool_client" "web_client" {
  name            = "enterprise-portal-web-client"
  user_pool_id    = aws_cognito_user_pool.client_directory.id
  generate_secret = false # Set to true if server-to-server client validation is required

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

# 4. Architect the Native API Gateway Cognito User Pool Authorizer
resource "aws_api_gateway_authorizer" "cognito_edge_gatekeeper" {
  name           = "enterprise-cognito-user-authorizer"
  rest_api_id    = data.aws_api_gateway_rest_api.ingress_gateway.id
  type           = "COGNITO_USER_POOLS"
  provider_arns  = [aws_cognito_user_pool.client_directory.arn]
  
  # IDENTITY VERIFICATION PARAMETER
  identity_source = "method.request.header.Authorization" # Extract bearer token directly from request header strings
}

# 5. Output the Authorizer ID to easily apply across explicit API method endpoints
output "cognito_authorizer_id" {
  value       = aws_api_gateway_authorizer.cognito_edge_gatekeeper.id
  description = "The edge authorizer ID used to lock method execution blocks inside your route files"
}
