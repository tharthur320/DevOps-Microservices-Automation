# =====================================================================
# CERTIFICATION SCENARIO 67: SOVEREIGN HYBRID CRYPTOGRAPHIC GOVERNANCE
# COMPONENT: AWS EXTERNAL KEY STORES (XKS) LINKED TO PRIVATE NETWORKS
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

# 1. Reference Your Existing Private Network Core Infrastructure
data "aws_vpc" "security_network" {
  id = "vpc-00000000000000000" # References your existing Phase 1 Core VPC ID
}

# 2. Reference the AWS PrivateLink Endpoint Service Bridging to On-Premises HSMs
# (This represents the private network tunnel cabled directly to your physical facility)
data "aws_vpc_endpoint_service" "hsm_proxy_service" {
  service_name = "com.amazonaws.vpce.us-east-1.vpce-svc-00000000000000000"
}

# 3. Create the Private Internal Interface Endpoint for the Cryptographic Proxy
resource "aws_vpc_endpoint" "xks_proxy_endpoint" {
  vpc_id              = data.aws_vpc.security_network.id
  service_name        = data.aws_vpc_endpoint_service.hsm_proxy_service.service_name
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = false

  subnet_ids = ["subnet-11111111", "subnet-22222222"] # Secure private subnet channels
}

# 4. Architect the Ironclad AWS KMS External Key Store (XKS) Appliance Configuration
resource "aws_kms_custom_key_store" "external_vault_bridge" {
  custom_key_store_name = "enterprise-external-hsm-keystore"
  custom_key_store_type = "EXTERNAL_KEY_STORE" # Mandates off-cloud key management scope

  # PROXY CONNECTIVITY LAYER: Pipes key calls privately over your network endpoint
  xks_proxy_connectivity = "VPC_ENDPOINT_SERVICE"
  xks_proxy_vpc_endpoint_service_name = data.aws_vpc_endpoint_service.hsm_proxy_service.service_name

  # Authentication Credentials for the External Proxy API Handshake
  # (In production, these URI paths and secret tokens are pulled dynamically from Vault/Secrets Manager)
  xks_proxy_uri_endpoint = "https://elitedevopsenterprise.com"
  xks_proxy_uri_path     = "/kms/xks/v1"
  
  # Base64-encoded secret access keys managing the cryptographic API signature
  xks_proxy_access_key_id = "XKS_PROXY_ACCESS_KEY_ID_BASELINE"

  tags = {
    Layer      = "Sovereign-Cryptographic-Fabric"
    SavedAsset = "True"
  }
}
