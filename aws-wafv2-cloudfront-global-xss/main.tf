# =====================================================================
# CERTIFICATION SCENARIO 155: GLOBAL EDGE THREAT NEUTRALIZATION
# COMPONENT: CLOUDFRONT-SCOPED WAFV2 DECODERS BLOCKING GLOBAL XSS EVASIONS
# =====================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# NOTE: For CloudFront global scope Web ACL deployments, you MUST explicitely 
# compile your infrastructure patterns using the us-east-1 provider mesh.
provider "aws" {
  region = "us-east-1"
}

# 1. Deploy the Master Global Self-Defending WAFv2 Web Access Control List
resource "aws_wafv2_web_acl" "global_cloudfront_shield" {
  name        = "enterprise-global-cloudfront-xss-shield"
  description = "Authoritative global edge perimeter blocking obfuscated XSS scripts on the CloudFront network"
  scope       = "CLOUDFRONT" # Mandates deployment to global edge locations natively
  
  default_action {
    allow {} # Permit legitimate, pre-filtered consumer traffic to proceed safely
  }

  # =====================================================================
  # RULE 1: DEEP-PACKET NORMALIZATION & ANTI-XSS ANALYSIS ENGINE
  # =====================================================================
  rule {
    name     = "BlockGlobalObfuscatedXSSInjections"
    priority = 1

    action {
      block {} # Drop matching malicious packets instantly at the global perimeter edge
    }

    statement {
      xss_match_statement {
        field_to_match {
          all_query_arguments {} # Scan all passing URL query string keys and parameter fields
        }

        # CRYPTOGRAPHIC NORMALIZATION PIPELINE: Strips away evasion scripts before checking signatures
        text_transformation {
          priority = 1
          type     = "URL_DECODE" # Resolves hex codes like %3C back to standard characters
        }

        text_transformation {
          priority = 2
          type     = "HTML_ENTITY_DECODE" # Decodes strings like &lt; to expose embedded script tags
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "GlobalWAFCloudFrontXSSMitigation"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "EnterpriseGlobalEdgeInboundWAF"
    sampled_requests_enabled   = true
  }

  tags = {
    Layer      = "Global-Perimeter-Edge-Defense"
    SavedAsset = "True"
  }
}

# 2. Output the Authoritative ARN to easily link to CloudFront CDN distributions
output "cloudfront_waf_web_acl_arn" {
  value       = aws_wafv2_web_acl.global_cloudfront_shield.arn
  description = "The global Web ACL ARN used to bind securely inside your CloudFront configuration blocks"
}
