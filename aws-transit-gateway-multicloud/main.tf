# =====================================================================
# CERTIFICATION SCENARIO 101: PRIVATE MULTI-CLOUD INTERCONNECTIVITY
# COMPONENT: AWS TRANSIT GATEWAY ROUTING EXPLICIT CROSS-CLOUD CORRIDORS
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

# 1. Reference Your Foundational Infrastructure VPC (Phase 1 Core Network)
data "aws_vpc" "datacenter_vpc" {
  id = "vpc-00000000000000000" 
}

data "aws_subnet" "private_app_a" {
  id = "subnet-11111111" # Private Application Subnet AZ-A
}

data "aws_subnet" "private_app_b" {
  id = "subnet-22222222" # Private Application Subnet AZ-B
}

# 2. Reference Your Central Infrastructure Route Tables (To Inject Multi-Cloud Paths)
data "aws_route_table" "private_rt" {
  subnet_id = data.aws_subnet.private_app_a.id
}

# 3. Deploy the Authoritative Multi-Cloud AWS Transit Gateway Router Hub
resource "aws_ec2_transit_gateway" "multi_cloud_hub" {
  description                     = "Centralized transport routing hub anchoring private cross-cloud connection corridors"
  amazon_side_asn                 = 64512 # Allocates a private Autonomous System Number for dynamic BGP routing
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"

  tags = {
    Layer      = "Transit-Gateway-Core"
    SavedAsset = "True"
  }
}

# 4. Securely Bind Your Private Datacenter VPC to the Transit Gateway Router
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_corridor" {
  subnet_ids         = [data.aws_subnet.private_app_a.id, data.aws_subnet.private_app_b.id]
  transit_gateway_id = aws_ec2_transit_gateway.multi_cloud_hub.id
  vpc_id             = data.aws_vpc.datacenter_vpc.id

  dns_support  = "enable"
  appliances_support = "disable" # Disabled to optimize raw packet transmission velocity
}

# 5. HARDENED EXAM PATTERN MAPPING: Inject Azure Route straight to Private Subnets
# This explicit block tells your local servers that if they try to route traffic 
# to the Azure VNet IP range, they must pass it straight to the Transit Gateway.
resource "aws_route" "route_to_azure_via_tgw" {
  route_table_id         = data.aws_route_table.private_rt.id
  destination_cidr_block = "10.200.0.0/16" # The explicit private IP footprint of your remote Azure environment
  transit_gateway_id     = aws_ec2_transit_gateway.multi_cloud_hub.id
}
