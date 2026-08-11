# =====================================================================
# CERTIFICATION SCENARIO 64: MULTI-ACCOUNT IDENTITY GOVERNANCE
# COMPONENT: AWS MANAGED MICROSOFT AD ENTERPRISE FOREST TRUST LINKS
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

# 1. Reference Your Existing Private Subnet Layout Corridors (Hub Subnets)
data "aws_subnet" "private_hub_a" {
  id = "subnet-11111111"
}

data "aws_subnet" "private_hub_b" {
  id = "subnet-22222222"
}

# 2. Deploy the Centralized AWS Managed Microsoft Active Directory (Tooling Hub)
resource "aws_directory_service_directory" "corporate_directory_hub" {
  name     = "://elitedevopsenterprise.com"
  password = "HardenedADMasterPass2026!" # Replaced via secure secrets parameters in production
  size     = "Enterprise"                # Spawns dedicated multi-node hardware domain controllers
  type     = "MicrosoftAD"
  edition  = "Enterprise"

  # NETWORK PLACEMENT LAYER: Restricts directory traffic strictly to private subnets
  vpc_settings {
    vpc_id     = "vpc-00000000000000000" # References your existing Phase 1 Core VPC ID
    subnet_ids = [data.aws_subnet.private_hub_a.id, data.aws_subnet.private_hub_b.id]
  }

  tags = {
    Layer      = "Central-Identity-Hub"
    SavedAsset = "True"
  }
}

# 3. Architect the Secure Cross-Account Active Directory Forest Trust Boundary
# (This master link maps a secure authentication corridor to your Production Account)
resource "aws_directory_service_trust" "cross_account_forest_trust" {
  directory_id = aws_directory_service_directory.corporate_directory_hub.id
  
  # TARGET DOMAIN CONFIGURATION: The target domain name string of your production account spoke
  remote_domain_name = "://elitedevopsenterprise.com"
  trust_password     = "SecureCrossAccountTrustKey2026!" # Cryptographic handshake key
  trust_direction    = "TWO_WAY"                         # Enables bidirectional cross-account verification
  trust_type         = "FOREST"                          # Connects the entire structural Active Directory forest root

  # Conditional DNS Routing: Directs Active Directory to resolve queries over private lines
  conditional_forwarder_ip_addrs = ["10.20.1.10", "10.20.1.20"] # Target production DNS resolvers
}
