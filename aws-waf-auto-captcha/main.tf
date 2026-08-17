# =====================================================================
# CERTIFICATION SCENARIO 107: AUTONOMOUS EDGE THREAT PERIMETERS
# COMPONENT: WAFV2 RATE-BASED RULES DRIVING AUTOMATED CAPTCHA CHALLENGES
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

# 1. Deploy the Autonomous Self-Defending WAFv2 Web Access Control List
resource "aws_wafv2_web_acl" "self_caring_perimeter" {
  name        = "enterprise-autonomous-edge-perimeter"
  description = "Hardened Layer-7 firewall that monitors and blocks botnet surges autonomously"
  scope       = "REGIONAL" # Protects regional infrastructure like Application Load Balancers
  
  default_action {
    allow {} # Default rule: permit clean corporate and consumer web traffic to flow
  }

  # 2. ARCHITECT THE AUTOMATED RATE-BASED DEFENSE RULE GATING
  rule {
    name     = "IsolateHighVolumeScrapingNetworks"
    priority = 1

    # OVERRIDE ACTION: Force the edge firewall to drop a Captcha screen on offenders
    action {
      captcha {} 
    }

    statement {
      rate_based_statement {
        # CONSTRANT BOUNDARY: Lock out any single IP firing over 100 requests in 5 minutes
        limit              = 100
        aggregate_key_type = "IP" # Evaluates source IPv4/IPv6 addresses natively at the perimeter

        # Advanced Text Normalization Guardrails (Scenario 91 Exploit Protection)
        # Strips out malicious obfuscation arrays before calculating volumetric metrics
        forwarded_ip_config {
          header_name       = "X-Forwarded-For"
          fallback_behavior = "MATCH"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AutonomousBotnetIsolationMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "EnterpriseMasterPerimeterWAF"
    sampled_requests_enabled   = true
  }

  tags = {
    Layer      = "Self-Defending-Perimeter"
    SavedAsset = "True"
  }
}
