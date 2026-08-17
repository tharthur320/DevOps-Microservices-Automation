# =====================================================================
# CERTIFICATION SCENARIO 145: AUTOMATED LAYER-7 PERIMETER HARDENING
# COMPONENT: WAFV2 DECODERS BLOCKING CROSS-SITE SCRIPTING (XSS) EVASIONS
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

# 1. Deploy the Authoritative Layer-7 Self-Defending WAFv2 Web Access Control List
resource "aws_wafv2_web_acl" "xss_hardened_perimeter" {
  name        = "enterprise-xss-hardened-perimeter"
  description = "Autonomous perimeter shielding backend compute pools from Cross-Site Scripting (XSS) evasions"
  scope       = "REGIONAL" # Placed directly in front of regional Application Load Balancers
  
  default_action {
    allow {} # Permit legitimate, pre-filtered traffic to proceed safely
  }

  # =====================================================================
  # RULE 1: ANTI-XSS SCRIPT EXPLOIT & TEXT NORMALIZATION PIPELINE
  # =====================================================================
  rule {
    name     = "InterceptObfuscatedXSSAttempts"
    priority = 1

    action {
      block {} # Drop matching malicious packets instantly at the perimeter
    }

    statement {
      xss_match_statement {
        field_to_match {
          all_query_arguments {} # Scan all passing URL parameters and form fields
        }

        # CRYPTOGRAPHIC NORMALIZATION: Strips away evasion scripts before checking strings
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
      metric_name                = "WAFEdgeXSSMitigationMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "EnterpriseGlobalIngressXSSWAF"
    sampled_requests_enabled   = true
  }

  tags = {
    Layer      = "Perimeter-Layer7-XSS-Defense"
    SavedAsset = "True"
  }
}
