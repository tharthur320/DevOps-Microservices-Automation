# =====================================================================
# CERTIFICATION SCENARIO 165: REGIONAL INGRESS THREAT NEUTRALIZATION
# COMPONENT: REGIONAL-SCOPED WAFV2 DECODERS BLOCKING DYNAMIC XSS EVASIONS
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

# 1. Reference Your Foundational Public Application Load Balancer Ingress (From Scenario 131)
data "aws_lb" "perimeter_alb" {
  name = "enterprise-production-core-alb"
}

# 2. Deploy the Master Regional Self-Defending WAFv2 Web Access Control List
resource "aws_wafv2_web_acl" "regional_alb_shield" {
  name        = "enterprise-regional-alb-xss-shield"
  description = "Authoritative regional perimeter blocking obfuscated XSS scripts on the application load balancer"
  scope       = "REGIONAL" # Mandates deployment to regional computing tiers natively
  
  default_action {
    allow {} # Permit legitimate, pre-filtered consumer traffic to proceed safely
  }

  # =====================================================================
  # RULE 1: DEEP-PACKET NORMALIZATION & ANTI-XSS ANALYSIS ENGINE
  # =====================================================================
  rule {
    name     = "BlockRegionalObfuscatedXSSInjections"
    priority = 1

    action {
      block {} # Drop matching malicious packets instantly at the regional perimeter edge
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
      metric_name                = "RegionalWAFALBXSSMitigation"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "EnterpriseRegionalIngressWAF"
    sampled_requests_enabled   = true
  }

  tags = {
    Layer      = "Regional-Perimeter-Edge-Defense"
    SavedAsset = "True"
  }
}

# 3. Securely Bind the Web ACL Directly to Your Regional Application Load Balancer
resource "aws_wafv2_web_acl_association" "alb_binding" {
  resource_arn = data.aws_lb.perimeter_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.regional_alb_shield.arn
}
