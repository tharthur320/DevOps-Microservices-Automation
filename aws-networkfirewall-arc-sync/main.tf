# =====================================================================
# CERTIFICATION SCENARIO 113: SELF-HEALING MULTI-REGION THREAT BARRIERS
# COMPONENT: AWS NETWORK FIREWALL MIRRORING TIED TO ROUTE 53 ARC CELLS
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
  region = "us-east-1" # Primary Data Center Infrastructure Boundary (Virginia)
}

provider "aws" {
  alias  = "west"
  region = "us-west-2" # Secondary Disaster Recovery Boundary (Oregon)
}

# 2. Deploy the Primary Network Firewall Stateful Rule Group (Virginia Hub)
resource "aws_networkfirewall_rule_group" "east_firewall_rules" {
  capacity = 100
  name     = "enterprise-global-threat-signatures-east"
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
          settings = ["\"Volumetric application exploit attempt intercepted at Virginia network boundary.\""]
        }
      }
    }
  }
}

# 3. Architect the Identical Synchronized Secondary Rule Group (Oregon Hub)
resource "aws_networkfirewall_rule_group" "west_firewall_rules" {
  provider = aws.west # CROSS-REGION ALIAS BINDING: Enforces deployment inside us-west-2
  capacity = 100
  name     = "enterprise-global-threat-signatures-west"
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
          settings = ["\"Volumetric application exploit attempt intercepted at Oregon network boundary.\""]
        }
      }
    }
  }
}

# 4. Reference Your Existing Global Route 53 ARC Resilient Cluster (From Scenario 100)
data "aws_route53_recovery_control_config_cluster" "global_cluster" {
  name = "enterprise-global-tier0-arc-cluster"
}

data "aws_route53_recovery_control_config_control_panel" "master_panel" {
  name        = "enterprise-master-traffic-panel"
  cluster_arn = data.aws_route53_recovery_control_config_cluster.global_cluster.arn
}

# 5. Connect the Multi-Region Security Gateways Straight to ARC Control Toggles
resource "aws_route53_recovery_control_config_routing_control" "east_perimeter_toggle" {
  name              = "us-east-1-firewall-gate"
  cluster_arn       = data.aws_route53_recovery_control_config_cluster.global_cluster.arn
  control_panel_arn = data.aws_route53_recovery_control_config_control_panel.master_panel.arn
}

resource "aws_route53_recovery_control_config_routing_control" "west_perimeter_toggle" {
  name              = "us-west-2-firewall-gate"
  cluster_arn       = data.aws_route53_recovery_control_config_cluster.global_cluster.arn
  control_panel_arn = data.aws_route53_recovery_control_config_control_panel.master_panel.arn
}
