# =====================================================================
# CERTIFICATION SCENARIO 195: AUTOMATED DATA LOG PRIVACY GOVERNANCE
# COMPONENT: WAFV2 LOGGING CONFIGURATIONS AUTOMATING CREDENTIAL REDACTIONS
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

# 1. Reference Your Central Active Ingress Application Load Balancer WAF (From Scenario 185)
data "aws_wafv2_web_acl" "header_enrichment_acl" {
  name  = "enterprise-edge-header-enrichment-perimeter"
  scope = "REGIONAL"
}

# 2. Reference Your High-Throughput Log Delivery Stream (From Scenario 143)
data "aws_kinesis_firehose_delivery_stream" "security_firehose" {
  name = "aws-network-firewall-alerts-delivery"
}

# 3. Architect the Authoritative Automated WAFv2 Logging & Redaction Policy
# This resource forces the edge plane to scrub out sensitive parameters before logging.
resource "aws_wafv2_web_acl_logging_configuration" "privacy_sanitizer" {
  log_destination_configs = [data.aws_kinesis_firehose_delivery_stream.security_firehose.arn]
  resource_arn            = data.aws_wafv2_web_acl.header_enrichment_acl.arn

  # IRONCLAD GOVERNANCE BINDING: The Data Masking Redaction Matrix
  # Instructs the logging engine to permanently replace token values with redacted placeholders.
  redacted_fields {
    single_header {
      name = "authorization" # Sanitizes corporate bearer token strings from header outputs
    }
  }

  redacted_fields {
    single_header {
      name = "x-enterprise-api-token" # Sanitizes dynamic application keys
    }
  }

  redacted_fields {
    single_query_argument {
      name = "access_token" # Sanitizes credential tokens passed inside query strings
    }
  }

  # Dynamic logging filters can be added below to drop background noise traffic completely
  logging_filter {
    default_behavior = "KEEP"

    filter {
      behavior = "KEEP"
      requirement = "MEETS_ANY"
      
      condition {
        action_condition {
          action = "BLOCK" # Prioritize logging blocked exploit attempts for forensics
        }
      }
    }
  }
}
