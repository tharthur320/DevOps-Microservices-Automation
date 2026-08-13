# =====================================================================
# CERTIFICATION SCENARIO 100: THE ULTIMATE ENTERPRISE INGRESS SWITCHBOARD
# COMPONENT: ROUTE 53 APPLICATION RECOVERY CONTROLLER CELL COUPLINGS
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

# 1. Provision the authoritative, Multi-Region ARC Routing Control Cluster
# (Spawns a highly resilient data plane across 5 redundant global regions)
resource "aws_route53_recovery_control_config_cluster" "global_cluster" {
  name = "enterprise-global-tier0-arc-cluster"
}

# 2. Deploy the Central Administrative Control Panel Container
resource "aws_route53_recovery_control_config_control_panel" "master_panel" {
  name        = "enterprise-master-traffic-panel"
  cluster_arn = aws_route53_recovery_control_config_cluster.global_cluster.arn
}

# 3. Architect the Dynamic Traffic Routing Toggle Switch for the US-East Region
resource "aws_route53_recovery_control_config_routing_control" "east_toggle" {
  name              = "us-east-1-traffic-gate"
  cluster_arn       = aws_route53_recovery_control_config_cluster.global_cluster.arn
  control_panel_arn = aws_route53_recovery_control_config_control_panel.master_panel.arn
}

# 4. Architect the Parallel Traffic Routing Toggle Switch for the US-West Region
resource "aws_route53_recovery_control_config_routing_control" "west_toggle" {
  name              = "us-west-2-traffic-gate"
  cluster_arn       = aws_route53_recovery_control_config_cluster.global_cluster.arn
  control_panel_arn = aws_route53_recovery_control_config_control_panel.master_panel.arn
}

# 5. HARDENED SAFETY BOUNDARY: Deploy the Failover Safety Rule Constraint Gating
# Forces a strict logical rule: At least one global gateway must remain open at all times.
resource "aws_route53_recovery_control_config_safety_rule" "prevent_blackout_rule" {
  name              = "assert-at-least-one-region-active"
  control_panel_arn = aws_route53_recovery_control_config_control_panel.master_panel.arn
  rule_config {
    inverted = false
    threshold = 1
    type      = "AT_LEAST_ONE" # Structural safety gate blocking dual-deactivation errors
  }

  # Bind both regional switches to be evaluated by this safety assertion
  asserted_controls = [
    aws_route53_recovery_control_config_routing_control.east_toggle.arn,
    aws_route53_recovery_control_config_routing_control.west_toggle.arn
  ]
}
