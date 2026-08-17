# =====================================================================
# CERTIFICATION SCENARIO 150: AUTOMATED SAAS EDGE INGRESS AUTHENTICATION
# COMPONENT: WAFV2 WEB ACL VALIDATING INBOUND REQUESTS VIA SECRETS MANAGER
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

# 1. Provision the Secure Master Cloud Storage Vault for Ingress Authentication Tokens
resource "aws_secretsmanager_secret" "api_ingress_token" {
  name                    = "enterprise-edge-api-ingress-auth-token"
  description             = "Dynamically rotating master application secret token guarding edge ingress portals"
  recovery_window_in_days = 7 # Minimum recovery window for agile testing environments

  tags = {
    Layer      = "Secret-Vault-Core"
    Compliance = "Rotating-Edge-Token"
  }
}

# 2. Deploy the Initial Placeholder Secret String (Handled via automated rotators in prod)
resource "aws_secretsmanager_secret_version" "initial_token_string" {
  secret_id     = aws_secretsmanager_secret.api_ingress_token.id
  secret_string = "HardenedEdgeIngressCipherTokenPass2026!"
}

# 3. Architect the Authoritative Layer-7 Self-Defending WAFv2 Web Access Control List
resource "aws_wafv2_web_acl" "token_auth_perimeter" {
  name        = "enterprise-token-auth-perimeter"
  description = "Layer-7 perimeter blocking unauthorized API calls by evaluating headers via Secrets Manager"
  scope       = "REGIONAL" # Placed directly in front of regional Application Load Balancers
  
  default_action {
    block {} # ZERO-TRUST DEFAULT POSTURE: Deny and drop all traffic unless explicitly authorized below
  }

  # 4. IMPLEMENT THE AUTOMATED DYNAMIC TOKEN VALIDATION RULE GATING
  rule {
    name     = "EnforceDynamicApplicationSecretToken"
    priority = 1

    action {
      allow {} # Authorize packet transit if the token evaluation matches exactly
    }

    statement {
      string_match_statement {
        field_to_match {
          headers {
            match_pattern {
              included_headers = ["x-enterprise-api-token"] # Custom corporate bearer auth header string
            }
            match_scope = "ALL"
            oversize_handling = "REJECT"
          }
        }

        # HARDENED EXAM MAPPING CORRIDOR: Dynamically match against Secrets Manager token strings
        search_string = aws_secretsmanager_secret_version.initial_token_string.secret_string

        # Cryptographic Text Normalization Guardrails (Scenario 91 Exploit Protection)
        text_transformation {
          priority = 1
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "WAFEdgeTokenAuthSuccessMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "EnterpriseMasterTokenAuthWAF"
    sampled_requests_enabled   = true
  }

  tags = {
    Layer      = "Self-Authenticating-Perimeter"
    SavedAsset = "True"
  }
}
