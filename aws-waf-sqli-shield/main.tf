# =====================================================================
# CERTIFICATION SCENARIO 40: LAYER-7 WEB DEEP-PACKET EXPLOIT DEFENSE
# COMPONENT: WAFV2 DEEP STRING ANALYSIS AND TEXT NORMALIZATION SYSTEMS
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Reference an Existing Kinesis Firehose Delivery Stream for Security Logs
# (This links our security logging configuration to our centralized telemetry bus)
data "aws_kinesis_firehose_delivery_stream" "central_firehose" {
  name = "aws-waf-logs-enterprise-aggregator" # Firehose for WAF MUST start with "aws-waf-logs-"
}

# 2. Architect the Hardened Layer-7 WAFv2 SQL Injection Defense Shield
resource "aws_wafv2_web_acl" "sqli_threat_shield" {
  name        = "enterprise-sqli-mitigation-shield"
  description = "Hardened edge web application firewall intercepting data manipulation exploits"
  scope       = "REGIONAL" # Placed directly in front of regional Application Load Balancers

  default_action {
    allow {} # Default posture allowing safe traffic to be evaluated by the string logic
  }

  rule {
    name     = "BlockSQLInjectionExploits"
    priority = 1

    action {
      block {} # INSTRUCTION: Instantly drop the TCP packet if an exploit is located
    }

    statement {
      or_statement {
        statement {
          # CLAUSE A: Deep-packet scanning inside the incoming URL query string parameters
          sqli_match_statement {
            field_to_match {
              query_string {}
            }
            
            # TEXT NORMALIZATION SEQUENCE: Strips obfuscation layers before string evaluation
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }

        statement {
          # CLAUSE B: Deep-packet scanning inside the application HTTP Request Body field
          sqli_match_statement {
            field_to_match {
              body {}
            }
            
            text_transformation {
              priority = 1
              type     = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type     = "HTML_ENTITY_DECODE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiExploitMitigationMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "MasterSQLiShieldGlobalMetric"
    sampled_requests_enabled   = true
  }
}

# 3. Deploy the Real-Time Security Auditing and Ingestion Logging Link
resource "aws_wafv2_web_acl_logging_configuration" "waf_log_binding" {
  log_destination_configs = [data.aws_kinesis_firehose_delivery_stream.central_firehose.arn]
  resource_arn            = aws_wafv2_web_acl.sqli_threat_shield.arn

  # Privacy Masking Rules: Redact sensitive financial tokens from raw forensic logs
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }
  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
}
