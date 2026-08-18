# =====================================================================
# CERTIFICATION SCENARIO 175: GLOBAL EDGE FLOOD NEUTRALIZATION
# COMPONENT: CLOUDFRONT WAFV2 ENFORCING ADVANCED KEYED RATE LIMITS
# =====================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# NOTE: Global CloudFront Web ACL rules MUST be compiled inside the us-east-1 regional plane
provider "aws" {
  region = "us-east-1"
}

# 1. Deploy the Global-Scoped Self-Defending WAFv2 Web Access Control List
resource "aws_wafv2_web_acl" "global_flood_shield" {
  name        = "enterprise-global-cloudfront-flood-shield"
  description = "Authoritative global edge perimeter blocking low-and-slow distributed botnets using composite keyed rate rules"
  scope       = "CLOUDFRONT" # Mandates native mapping over global edge CDN locations
  
  default_action {
    allow {} # Permit clean, pre-filtered consumer traffic to proceed safely
  }

  # =====================================================================
  # RULE 1: ADAPTIVE DYNAMIC COMPOSITE RATE-BASED ENGINE
  # =====================================================================
  rule {
    name     = "IsolateDistributedTokenFloods"
    priority = 1

    action {
      block {} # Drop matching malicious packets instantly at the perimeter edge
    }

    statement {
      rate_based_statement {
        limit              = 100 # Tight ceiling: maximum 100 requests permitted per 5-minute window
        evaluation_window_sec = 300

        # ADVANCED COMPOSITE KEYED TRACKING
        # Tracks traffic velocities by coupling the client source IP straight to their authorization header token
        custom_key {
          ip {}
        }

        custom_key {
          header {
            name       = "x-enterprise-client-tier"
            text_transformation {
              priority = 1
              type     = "NONE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "GlobalWAFCompositeRateLimiting"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "EnterpriseGlobalEdgeFloodWAF"
    sampled_requests_enabled   = true
  }

  tags = {
    Layer      = "Global-Perimeter-Edge-Defense"
    SavedAsset = "True"
  }
}

# 2. Output the Global Web ACL Identifier to attach directly onto CDN configurations
output "global_flood_waf_arn" {
  value       = aws_wafv2_web_acl.global_flood_shield.arn
  description = "The global Web ACL ARN used to bind securely inside your CloudFront configuration blocks"
}
