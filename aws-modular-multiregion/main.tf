# =====================================================================
# CERTIFICATION SCENARIO 35: REUSABLE GLOBAL MULTI-REGION TOPOGRAPHIES
# COMPONENT: TERRAFORM MODULES AND EXPLICIT PROVIDER ALIAS CLUSTERS
# =====================================================================

# 1. Initialize Regional Provider Configurations
provider "aws" {
  region = "us-east-1" # Primary Data Center Ingress Hub (Virginia)
}

provider "aws" {
  alias  = "west"
  region = "us-west-2" # Disaster Recovery Infrastructure Hub (Oregon)
}

# 2. Deploy the Primary Region Infrastructure Core via Reusable Modules
module "primary_datacenter" {
  source = "./modules/datacenter_vpc"

  # Pass the default us-east-1 provider context straight into the module
  providers = {
    aws = aws
  }

  environment_name   = "production-east"
  network_cidr_block = "10.150.0.0/16"
}

# 3. Deploy the Identical Secondary Region Core via the EXACT SAME Module
module "secondary_datacenter" {
  source = "./modules/datacenter_vpc"

  # CROSS-REGION PROVIDER ALIAS ALIGNMENT: 
  # Forces this module block to build its resources inside Oregon (us-west-2)
  providers = {
    aws = aws.west
  }

  environment_name   = "production-west"
  network_cidr_block = "10.160.0.0/16" # Separate address allocation prevents IP collisions
}

# =====================================================================
# MODULE BLUEPRINT DEFINITION FILE (Stored in ./modules/datacenter_vpc/main.tf)
# =====================================================================
/*
variable "environment_name" { type = string }
variable "network_cidr_block" { type = string }

resource "aws_vpc" "modular_network" {
  cidr_block           = var.network_cidr_block
  enable_dns_hostnames = true
  tags = {
    Name        = "${var.environment_name}-network-core"
    SavedAsset  = "True"
  }
}

resource "aws_subnet" "modular_subnet" {
  vpc_id            = aws_vpc.modular_network.id
  cidr_block        = cidrsubnet(var.network_cidr_block, 8, 1)
  availability_zone = "${data.aws_region.current.name}a"
  tags = {
    Name = "${var.environment_name}-isolated-subnet"
  }
}

data "aws_region" "current" {}
*/
