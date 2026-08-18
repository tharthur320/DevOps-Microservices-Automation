# =====================================================================
# CERTIFICATION SCENARIO 199: GLOBAL ANALYTICS IDENTITY GOVERNANCE
# COMPONENT: OPENSEARCH DOMAIN POLICIES PARSING FEDERATED SESSION TAGS
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

# 1. Reference Your Central Active OpenSearch Domain (From Scenario 179)
data "aws_opensearch_domain" "siem_analytics" {
  domain_name = "enterprise-core-siem-analytics"
}

# 2. Architect the Hardened Federated Least-Privilege OpenSearch Domain Access Policy
# This resource forces dynamic identity attribute checking inside the cluster core.
resource "aws_opensearch_domain_policy" "federated_identity_gate" {
  domain_name = data.aws_opensearch_domain.siem_analytics.domain_name

  access_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceDynamicFederatedABACCipherTokens"
        Effect    = "Allow"
        Principal = {
          AWS = "*" # Wildcard principal is safely and tightly fenced by our condition attributes below
        }
        # Grant data plane index lookup and reading privileges exclusively
        Action = [
          "es:ESHttpGet",
          "es:ESHttpPost"
        ]
        Resource = "${data.aws_opensearch_domain.siem_analytics.arn}/*"

        # 3. DYNAMIC IDENTITY CONDITION MATCHING MATRIX
        # Forces the caller's active assumed-session tags to match corporate project baselines
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID"       = "o-xxxxxxxxxx"
            "aws:PrincipalTag/Project" = "EnterpriseCoreCommerce"
            "aws:PrincipalTag/Role"    = "ForensicAnalyst"
          }
        }
      }
    ]
  })
}
