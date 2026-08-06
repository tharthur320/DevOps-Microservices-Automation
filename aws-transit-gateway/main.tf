# =====================================================================
# PROJECT: HYBRID ENTERPRISE NETWORKING (AWS TRANSIT GATEWAY HUB)
# COMPONENT: CENTRALIZED CLOUD ROUTER BINDING ISOLATED BUSINESS VNECS
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Architect the Primary Centralized Transit Gateway (The Cloud Router)
resource "aws_transit_gateway" "network_hub" {
  description                     = "Enterprise-Core-Transit-Gateway-Hub"
  amazon_side_asn                 = 64512 # Assigns a private Autonomous System Number for BGP routing
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"

  tags = {
    Layer      = "Global-Routing"
    SavedAsset = "True"
  }
}

# 2. Reference Isolated Business Network A (Corporate Operations Network)
resource "aws_vpc" "corporate_vpc" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "Corporate-Ops-Network" }
}

resource "aws_subnet" "corp_subnet" {
  vpc_id            = aws_vpc.corporate_vpc.id
  cidr_block        = "10.10.1.0/24"
  availability_zone = "us-east-1a"
}

# 3. Reference Isolated Business Network B (Production Application Network)
resource "aws_vpc" "production_vpc" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "Production-App-Network" }
}

resource "aws_subnet" "prod_subnet" {
  vpc_id            = aws_vpc.production_vpc.id
  cidr_block        = "10.20.1.0/24"
  availability_zone = "us-east-1a"
}

# 4. Bind Isolated Network A Securely to the Central Router Hub
resource "aws_transit_gateway_vpc_attachment" "corp_attachment" {
  transit_gateway_id = aws_transit_gateway.network_hub.id
  vpc_id             = aws_vpc.corporate_vpc.id
  subnet_ids         = [aws_subnet.corp_subnet.id]
  tags               = { Name = "TGW-Corporate-Attachment" }
}

# 5. Bind Isolated Network B Securely to the Central Router Hub
resource "aws_transit_gateway_vpc_attachment" "prod_attachment" {
  transit_gateway_id = aws_transit_gateway.network_hub.id
  vpc_id             = aws_vpc.production_vpc.id
  subnet_ids         = [aws_subnet.prod_subnet.id]
  tags               = { Name = "TGW-Production-Attachment" }
}
