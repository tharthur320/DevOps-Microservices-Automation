# =====================================================================
# CERTIFICATION SCENARIO 94: MULTI-REGION SECURITY PERIMETER SYNC
# COMPONENT: TERRAFORM PROVIDER ALIASES MIRRORING NETWORK FIREWALL RULES
# =====================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 1. Initialize Regional Provider Configurations
provider "aws" {
  region = "us-east-1" # Primary Data Center Security Region (Virginia)
}

provider "aws" {
  alias  = "west"
  region = "us-west-2" # Disaster Recovery Network Region (Oregon)
}

# 2. Deploy the Primary Network Firewall Rule Group (Virginia Hub)
resource "aws_networkfirewall_rule_group" "primary_firewall_rules" {
  capacity = 100
  name     = "enterprise-global-threat-signatures"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      stateful_rule {
        action = "DROP"
        header {
          direction        = "ANY"
          source           = "ANY"
          source_port      = "ANY"
          destination      = "ANY"
          destination_port = "ANY"
          protocol         = "HTTP"
        }
        rule_option {
          keyword  = "sid"
          settings = ["1000001"]
        }
        rule_option {
          keyword  = "msg"
          settings = ["\"Volumetric application exploit or malicious HTTP header sequence intercepted at boundary.\""]
        }
      }
    }
  }

  tags = {
    Layer      = "Primary-Network-Perimeter"
    SavedAsset = "True"
  }
}

# 3. Architect the Identical Secondary Rule Group (Oregon Hub)
# (Uses the EXACT SAME rule configuration parameters but compiles over the West provider)
resource "aws_networkfirewall_rule_group" "secondary_firewall_rules" {
  provider = aws.west # CROSS-REGION ALIAS BINDING: Enforces deployment inside Oregon
  capacity = 100
  name     = "enterprise-global-threat-signatures"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      stateful_rule {
        action = "DROP"
        header {
          direction        = "ANY"
          source           = "ANY"
          source_port      = "ANY"
          destination      = "ANY"
          destination_port = "ANY"
          protocol         = "HTTP"
        }
        rule_option {
          keyword  = "sid"
          settings = ["1000001"]
        }
        rule_option {
          keyword  = "msg"
          settings = ["\"Volumetric application exploit or malicious HTTP header sequence intercepted at boundary.\""]
        }
      }
    }
  }

  tags = {
    Layer      = "DisasterRecovery-Network-Perimeter"
    SavedAsset = "True"
  }
}
