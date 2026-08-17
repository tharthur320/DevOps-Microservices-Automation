# =====================================================================
# CERTIFICATION SCENARIO 120: AUTOMATED LAYER-7 PERIMETER HARDENING
# COMPONENT: WAFV2 DECODERS BLOCKING EXPLOIT EVASIONS & SANCTIONED GEOS
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
resource "aws_wafv2_web_acl" "hardened_edge_firewall" {
  name        = "enterprise-hardened-edge-firewall"
  description = "Autonomous perimeter shielding backend pools from SQLi evasion and geo-sanctioned traffic"
  scope       = "REGIONAL" # Placed directly in front of regional Application Load Balancers
  
  default_action {
    allow {} # Permit legitimate, pre-filtered traffic to proceed safely
  }

  # =====================================================================
  # RULE 1: ANTI-SQL INJECTION EXPLOIT & TEXT NORMALIZATION PIPELINE
  # =====================================================================
  rule {
    name     = "InterceptObfuscatedSQLiAttempts"
    priority = 1

    action {
      block {} # Drop matching malicious packets instantly at the perimeter
    }

    statement {
      sqli_match_statement {
        field_to_match {
          all_query_arguments {} # Scan all passing URL parameters and form fields
        }

        # CRYPTOGRAPHIC NORMALIZATION: Strips away evasion scripts before checking strings
        text_transformation {
          priority = 1
          type     = "URL_DECODE" # Resolves hex codes like %20 back to standard spacing
        }

        text_transformation {
          priority = 2
          type     = "HTML_ENTITY_DECODE" # Decodes strings like &quot; to expose embedded sql commands
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "WAFEdgeSQLiMitigationMetric"
      sampled_requests_enabled   = true
    }
  }

  # =====================================================================
  # RULE 2: RIGID GEOGRAPHIC FENCING & COMPLIANCE GUARDRAIL
  # =====================================================================
  rule {
    name     = "EnforceGeographicTradeSanctions"
    priority = 2

    action {
      block {} # Drop traffic from unauthorized locations instantly
    }

    statement {
      geo_match_statement {
        # Restrict ingress traffic from specific, high-risk sanctioned regions
        country_codes = ["NK", "IR", "SY"] 
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "WAFEdgeGeoBlockingMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "EnterpriseGlobalIngressWAF"
    sampled_requests_enabled   = true
  }

  tags = {
    Layer      = "Perimeter-Layer7-Defense"
    SavedAsset = "True"
  }
}
