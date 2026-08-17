# =====================================================================
# CERTIFICATION SCENARIO 158: HARDENED SOFTWARE-DEFINED NETWORKS
# COMPONENT: TRANSIT GATEWAY ROUTE TABLES ENFORCING EXPLICIT BLACKHOLES
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

# 1. Reference Your Central Active Multi-Cloud Transit Gateway Hub (From Scenario 101)
data "aws_ec2_transit_gateway" "central_router_hub" {
  filter {
    name   = "tag:Layer"
    values = ["Transit-Gateway-Core"]
  }
}

# 2. Reference the Isolated Active VPC Attachments (From Scenario 101 / Infrastructure Layouts)
data "aws_ec2_transit_gateway_vpc_attachment" "production_vpc_attachment" {
  filter {
    name   = "tag:Environment"
    values = ["Production"]
  }
}

data "aws_ec2_transit_gateway_vpc_attachment" "development_vpc_attachment" {
  filter {
    name   = "tag:Environment"
    values = ["Development"]
  }
}

# =====================================================================
# HARDENED NETWORKING PLANE: MULTI-TENANT ROUTING SEGMENTATION
# =====================================================================

# 3. Provision a Dedicated Route Table Dedicated to Production Environments
resource "aws_ec2_transit_gateway_route_table" "production_route_table" {
  transit_gateway_id = data.aws_ec2_transit_gateway.central_router_hub.id

  tags = {
    Name       = "production-isolated-tgw-routes"
    Layer      = "Network-Control-Plane"
    SavedAsset = "True"
  }
}

# 4. Provision a Separate Route Table Dedicated to Development Environments
resource "aws_ec2_transit_gateway_route_table" "development_route_table" {
  transit_gateway_id = data.aws_ec2_transit_gateway.central_router_hub.id

  tags = {
    Name       = "development-sandboxed-tgw-routes"
    Layer      = "Network-Control-Plane"
    SavedAsset = "True"
  }
}

# 5. Bind the Respective VPC Attachments to Their Dedicated Route Table Matrices
resource "aws_ec2_transit_gateway_route_table_association" "production_association" {
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_vpc_attachment.production_vpc_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.production_route_table.id
}

resource "aws_ec2_transit_gateway_route_table_association" "development_association" {
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_vpc_attachment.development_vpc_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.development_route_table.id
}

# =====================================================================
# IRONCLAD EDGE ISOLATION ENFORCEMENT: THE BLACKHOLE RULE
# =====================================================================

# 6. Inject a Hard Blackhole Route to Block Development from Ever Hitting Production Ranges
# This explicit block completely stops packets at the core routing engine plane layer.
resource "aws_ec2_transit_gateway_route" "dev_to_prod_blackhole" {
  destination_cidr_block         = "10.100.0.0/16" # The explicit private IP footprint of your Production VPC
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.development_route_table.id
  blackhole                      = true # DROPS ENTIRELY: Instantly kills cross-tenant packet transit
}
