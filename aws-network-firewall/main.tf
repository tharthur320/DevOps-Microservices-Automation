# =====================================================================
# CERTIFICATION SCENARIO 61: CENTRALIZED NETWORK BOUNDARY PERIMETERS
# COMPONENT: AWS NETWORK FIREWALL ENFORCING DEEP-PACKET RULES POLICY
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

# 1. Reference Your Foundational Data Center VPC Core Boundary
data "aws_vpc" "core_network" {
  id = "vpc-00000000000000000" # References your existing Phase 1 Core VPC ID
}

# 2. Deploy a Stateful Custom Rule Group Blocking Malicious Outbound Connections
resource "aws_networkfirewall_rule_group" "drop_unauthorized_egress" {
  capacity = 100
  name     = "drop-unapproved-outbound-protocols"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      stateful_rule {
        action = "DROP"
        header {
          direction        = "FORWARD"
          source           = "ANY"
          source_port      = "ANY"
          destination      = "ANY"
          destination_port = "ANY"
          protocol         = "SSH" # Drop any unauthorized SSH outbound tunneling attempts
        }
        rule_option {
          keyword  = "sid"
          settings = ["1"]
        }
        rule_option {
          keyword  = "msg"
          settings = ["\"Unauthorized outbound SSH tunnel intercepted and dropped at network perimeter.\""]
        }
      }
    }
  }
}

# 3. Compile the Master Firewall Policy Framework Controller
resource "aws_networkfirewall_firewall_policy" "perimeter_policy" {
  name = "enterprise-master-perimeter-firewall-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_stateful"]
    stateless_fragment_default_actions = ["aws:forward_to_stateful"]

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.drop_unauthorized_egress.arn
    }
  }
}

# 4. Deploy the AWS Network Firewall Inline Inspection Appliance
resource "aws_networkfirewall_firewall" "perimeter_shield" {
  name                = "enterprise-data-center-network-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.perimeter_policy.arn
  vpc_id              = data.aws_vpc.core_network.id

  # NETWORK PLACEMENT LAYER: Map the firewall to your dedicated inspection subnets
  subnet_mapping {
    subnet_id = "subnet-11111111" # Inspection Subnet AZ-A
  }
  subnet_mapping {
    subnet_id = "subnet-22222222" # Inspection Subnet AZ-B
  }

  tags = {
    Layer      = "Central-Perimeter-Firewall"
    SavedAsset = "True"
  }
}
