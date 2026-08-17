# =====================================================================
# CERTIFICATION SCENARIO 148: HIGH-AVAILABILITY PRIVATE NETWORKING
# COMPONENT: VPC PEERING CONNECTION STRUCTURING TRANSIT GATEWAY FALLBACKS
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

# 1. Reference Your Central Cross-Zone VPC Network Environments
data "aws_vpc" "primary_compute_vpc" {
  id = "vpc-00000000000000000" # Phase 1 Core App VPC
}

data "aws_vpc" "analytics_data_vpc" {
  id = "vpc-11111111111111111" # Central Reporting Analytics VPC
}

# 2. Reference the Target Private Subnet Route Tables to Inject Redundant Paths
data "aws_route_table" "compute_private_rt" {
  subnet_id = "subnet-11111111" # Private Application Subnet Hallway
}

# 3. Reference Your Active Centralized AWS Transit Gateway Hub (From Scenario 101)
data "aws_ec2_transit_gateway" "central_backbone" {
  filter {
    name   = "tag:Layer"
    values = ["Transit-Gateway-Core"]
  }
}

# 4. Architect the Redundant Point-to-Point Private VPC Peering Corridor
resource "aws_vpc_peering_connection" "failover_peering" {
  peer_vpc_id = data.aws_vpc.analytics_data_vpc.id
  vpc_id      = data.aws_vpc.primary_compute_vpc.id
  auto_accept = true # Automatically completes the trust handshake within a single management account

  tags = {
    Layer      = "Network-Failover-Corridor"
    SavedAsset = "True"
  }
}

# =====================================================================
# HARDENED EXAM ROUTING MATRIX: THE DUAL-TRANSIT NETWORK TOPOLOGY
# =====================================================================

# PATH A: The Primary Centralized Ingress Backbone (Transit Gateway Route)
resource "aws_route" "primary_tgw_route" {
  route_table_id         = data.aws_route_table.compute_private_rt.id
  destination_cidr_block = "10.200.0.0/16" # Analytics VNet/VPC Data Target Range
  transit_gateway_id     = data.aws_ec2_transit_gateway.central_backbone.id
}

# PATH B: The Standby Point-to-Point Direct Tunnel (VPC Peering Backup Route)
# NOTE: In an actual enterprise datacenter context, routing metrics or specific 
# longer prefixes are applied so that if Path A fails or its interface goes down,
# traffic automatically shifts to this active point-to-point peering gateway.
resource "aws_route" "backup_peering_route" {
  route_table_id            = data.aws_route_table.compute_private_rt.id
  destination_cidr_block    = "10.200.10.0/24" # High-priority database subnet within the analytics footprint
  vpc_peering_connection_id = aws_vpc_peering_connection.failover_peering.id
}
