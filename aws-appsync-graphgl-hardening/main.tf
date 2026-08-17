# =====================================================================
# CERTIFICATION SCENARIO 170: SECURE API EDGE INGRESS ARCHITECTURES
# COMPONENT: AWS APPSYNC GRAPHQL HARDENING COUPLED WITH WAFV2 ACCESS LOCKS
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

# 1. Reference Your Existing Layer-7 Self-Defending Firewall (From Scenario 107)
data "aws_wafv2_web_acl" "edge_perimeter" {
  name  = "enterprise-autonomous-edge-perimeter"
  scope = "REGIONAL"
}

# 2. Provision the Master Secure AWS AppSync GraphQL API Ingress Engine
resource "aws_appsync_graphql_api" "hardened_graphql_api" {
  name                = "enterprise-financial-graphql-mesh"
  authentication_type = "API_KEY" # Baseline validation token (Paired with WAF defenses below)

  # OBSERVABILITY LOGGING LAYER
  # Streams execution query paths directly to CloudWatch to ensure granular audit trails
  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_logging_role.arn
    field_log_level          = "ALL" # Capture complete metadata query shapes for forensic analysis
    exclude_verbose_content  = false
  }

  tags = {
    Layer      = "API-Ingress-GraphQL"
    SavedAsset = "True"
  }
}

# 3. Create the Secure IAM Logging Role for AppSync Control Plane Monitoring
resource "aws_iam_role" "appsync_logging_role" {
  name = "DataCenter-AppSync-CloudWatchLogging-ExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "appsync_logs_binding" {
  role       = aws_iam_role.appsync_logging_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppSyncPushToCloudWatchLogs"
}

# =====================================================================
# HARDENED API BOUNDARY ENFORCEMENT: THE INTERCEPT CORRIDOR
# =====================================================================

# 4. Bind Your Defending WAFv2 Web ACL Directly onto the GraphQL Endpoint
# This native link intercepts and drops malicious nested payloads at the edge plane
resource "aws_wafv2_web_acl_association" "appsync_waf_binding" {
  resource_arn = aws_appsync_graphql_api.hardened_graphql_api.arn
  web_acl_arn  = data.aws_wafv2_web_acl.edge_perimeter.arn
}

# 5. Deploy an Initial Long-Lived API Key for External Client Validations
resource "aws_appsync_api_key" "commerce_client_key" {
  api_id      = aws_appsync_graphql_api.hardened_graphql_api.id
  description = "Regulated external programmatic consumer validation token"
  expires     = "2027-12-31T23:59:59Z" # Force an un-extendable architectural token ceiling
}
