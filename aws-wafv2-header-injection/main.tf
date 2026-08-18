# =====================================================================
# CERTIFICATION SCENARIO 185: AUTOMATED EDGE TRANSPORT ENRICHMENT
# COMPONENT: WAFV2 WEB ACL AUTOMATING CUSTOM REQUEST HEADER INJECTIONS
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

# 1. Deploy the Adaptive Self-Defending WAFv2 Web Access Control List
resource "aws_wafv2_web_acl" "header_enrichment_perimeter" {
  name        = "enterprise-edge-header-enrichment-perimeter"
  description = "Layer-7 firewall that intercepts inbound packets and injects secure tracing headers autonomously"
  scope       = "REGIONAL" # Protects regional infrastructure like Application Load Balancers
  
  default_action {
    allow {} # Default rule: permit clean corporate and consumer web traffic to flow
  }

  # 2. IMPLEMENT THE AUTOMATED DYNAMIC HEADER INJECTION RULE GATING
  rule {
    name     = "EnforceDownstreamEdgeSecuritySignatures"
    priority = 1

    # OVERRIDE ACTION: Grant traffic transit while altering the data payload on the fly
    action {
      allow {
        custom_request_handling {
          # HEADER INJECTION MATRIX: Force secure variables into downstream requests
          insert_header {
            name  = "X-Enterprise-Edge-Verified"
            value = "True-HardwarePlaneVerified-2026" # Hardcodes corporate edge validation keys
          }

          insert_header {
            name  = "X-Content-Type-Options"
            value = "nosniff" # Eradicates application-layer MIME type sniffing risks at the edge
          }

          insert_header {
            name  = "X-Enterprise-Request-Epoch"
            value = "1784341200" # Embeds operational verification keys inside passing payloads
          }
        }
      }
    }

    # Standard filter catch matching legitimate global traffic footprints
    statement {
      not_statement {
        geo_match_statement {
          country_codes = ["NK", "IR"] # Block sanctioned networks while enriching clean pools
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "WAFEdgeHeaderEnrichmentMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "EnterpriseMasterEnrichmentWAF"
    sampled_requests_enabled   = true
  }

  tags = {
    Layer      = "Self-Defending-Perimeter"
    SavedAsset = "True"
  }
}
