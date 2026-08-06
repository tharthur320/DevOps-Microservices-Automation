# =====================================================================
# PROJECT: PERIMETER SUBSYSTEM SECURITY (STATELESS NETWORK ACLS)
# COMPONENT: IRONCLAD SUBNET-LEVEL CHECKPOINTS FOR ENTERPRISE DATA VAULTS
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Reference Your Base Data Center Network Core Boundary
resource "aws_vpc" "data_center_vpc" {
  cidr_block           = "10.90.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "DataCenter-Core-Network" }
}

# 2. Deploy a Highly Sensitive Database Subnet Tier
resource "aws_subnet" "database_subnet" {
  vpc_id            = aws_vpc.data_center_vpc.id
  cidr_block        = "10.90.20.0/24"
  availability_zone = "us-east-1a"
  tags                 = { Name = "Isolated-Database-Hallway" }
}

# 3. Architect the Stateless Network Access Control List (NACL) Shield
resource "aws_network_acl" "database_nacl" {
  vpc_id     = aws_vpc.data_center_vpc.id
  subnet_ids = [aws_subnet.database_subnet.id] # Enforces the checkpoint right at the entryway of the subnet

  # RULE 100: Allow Trusted Internal Applications to Connect on Port 5432 (PostgreSQL Data Stream)
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.90.1.0/24" # Whitelists only our internal application tier subnet
    from_port  = 5432
    to_port    = 5432
  }

  # RULE 200: Allow Ephemeral Return Traffic (Mandatory for Stateless Operations)
  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # EGRESS RULE 100: Allow outbound return data streams to find their way home
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Layer      = "Subnet-Perimeter-FW"
    SavedAsset = "True"
  }
}
