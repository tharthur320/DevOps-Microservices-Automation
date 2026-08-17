# =====================================================================
# CERTIFICATION SCENARIO 135: GITOPS NETWORK COMPLIANCE MESHES
# COMPONENT: MULTI-REGION PROVIDERS AUTOMATING FIREWALL RULE MIRRORING
# =====================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 1. Initialize Regional Provider Alignments Natively
provider "aws" {
  region = "us-east-1" # Primary Data Center Security Hub (Virginia)
}

provider "aws" {
  alias  = "west"
  region = "us-west-2" # Disaster Recovery Network Hub (Oregon)
}

# 2. Architect the Version-Controlled Stateful Rule Parameters
# (This local variable structures the uniform rule blocking malicious traffic)
locals {
  firewall_rules_source = {
    stateful_rule = [{
      action = "DROP"
      header = {
        direction        = "ANY"
        source           = "ANY"
        source_port      = "ANY"
        destination      = "ANY"
        destination_port = "ANY"
        protocol         = "HTTP"
      }
      rule_option = [
        {
          keyword  = "sid"
          settings = ["1000002"]
        },
        {
          keyword  = "msg"
          settings = ["\"GitOps Enforced Perimeter Block: Unauthorized or malicious payload intercepted at boundary.\""]
        }
      ]
    }]
  }
}

# 3. Deploy the Master GitOps Rule Group to the Primary Region (Virginia)
resource "aws_networkfirewall_rule_group" "east_gitops_rules" {
  capacity = 100
  name     = "enterprise-gitops-threat-signatures-east"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      dynamic "stateful_rule" {
        for_each = local.firewall_rules_source.stateful_rule
        content {
          action = stateful_rule.value.action
          header {
            direction        = stateful_rule.value.header.direction
            source           = stateful_rule.value.header.source
            source_port      = stateful_rule.value.header.source_port
            destination      = stateful_rule.value.header.destination
            destination_port = stateful_rule.value.header.destination_port
            protocol         = stateful_rule.value.header.protocol
          }
          dynamic "rule_option" {
            for_each = stateful_rule.value.rule_option
            content {
              keyword  = rule_option.value.keyword
              settings = rule_option.value.settings
            }
          }
        }
      }
    }
  }

  tags = {
    Layer      = "GitOps-Primary-Perimeter"
    SavedAsset = "True"
  }
}

# 4. Deploy the Identical, Mirrored Rule Group to the Secondary Region (Oregon)
# (Uses the exact same local variables block, but compiles over the West regional provider)
resource "aws_networkfirewall_rule_group" "west_gitops_rules" {
  provider = aws.west # CROSS-REGION BINDING: Force compile inside us-west-2
  capacity = 100
  name     = "enterprise-gitops-threat-signatures-west"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      dynamic "stateful_rule" {
        for_each = local.firewall_rules_source.stateful_rule
        content {
          action = stateful_rule.value.action
          header {
            direction        = stateful_rule.value.header.direction
            source           = stateful_rule.value.header.source
            source_port      = stateful_rule.value.header.source_port
            destination      = stateful_rule.value.header.destination
            destination_port = stateful_rule.value.header.destination_port
            protocol         = stateful_rule.value.header.protocol
          }
          dynamic "rule_option" {
            for_each = stateful_rule.value.rule_option
            content {
              keyword  = rule_option.value.keyword
              settings = rule_option.value.settings
            }
          }
        }
      }
    }
  }

  tags = {
    Layer      = "GitOps-DisasterRecovery-Perimeter"
    SavedAsset = "True"
  }
}
