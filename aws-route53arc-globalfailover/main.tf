# =====================================================================
# CERTIFICATION SCENARIO 191: HIGH-AVAILABILITY GLOBAL ROUTING CORRIDORS
# COMPONENT: ROUTE 53 APPLICATION RECOVERY CONTROLLER SWITCHBOARD CELLS
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

# 1. Provision the Resilient Route 53 ARC Cluster Infrastructure
# This resource deploys five highly available endpoint cells across global AWS regions.
resource "aws_route53recoverycontrolconfig_cluster" "global_dr_cluster" {
  name = "enterprise-global-tier0-arc-cluster"

  tags = {
    Layer      = "Global-Disaster-Recovery"
    SavedAsset = "True"
  }
}

# 2. Deploy the Authoritative Central Control Panel Management Grid
resource "aws_route53recoverycontrolconfig_control_panel" "master_traffic_panel" {
  name        = "enterprise-master-traffic-panel"
  cluster_arn = aws_route53recoverycontrolconfig_cluster.global_dr_cluster.arn
}

# 3. Create the Primary Datacenter Traffic Steering Control Switch (Virginia Hub)
resource "aws_route53recoverycontrolconfig_routing_control" "primary_east_switch" {
  name              = "us-east-1-primary-traffic-gate"
  cluster_arn       = aws_route53recoverycontrolconfig_cluster.global_dr_cluster.arn
  control_panel_arn = aws_route53recoverycontrolconfig_control_panel.master_traffic_panel.arn
}

# 4. Create the Standby Datacenter Traffic Steering Control Switch (Oregon Hub)
resource "aws_route53recoverycontrolconfig_routing_control" "standby_west_switch" {
  name              = "us-west-2-standby-traffic-gate"
  cluster_arn       = aws_route53recoverycontrolconfig_cluster.global_dr_cluster.arn
  control_panel_arn = aws_route53recoverycontrolconfig_control_panel.master_traffic_panel.arn
}

# 5. Output the Resilient Endpoint Cell Access Gateways
# These endpoints are referenced by automated scripts to issue sub-second route mutations.
output "arc_cluster_endpoints" {
  value       = aws_route53recoverycontrolconfig_cluster.global_dr_cluster.cluster_endpoints
  description = "The five region-isolated endpoint cells used to transmit emergency sub-second failover commands"
}
