# =====================================================================
# CERTIFICATION SCENARIO 156: GLOBAL CRYPTOGRAPHIC MESH RESILIENCE
# COMPONENT: KMS REPLICA KEYS SECURING MULTI-REGION DATA PLANE FALLBACKS
# =====================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Primary Region Network Provider (Virginia Hub)
provider "aws" {
  region = "us-east-1"
}

# Secondary Region Network Provider (Oregon Disaster Recovery Hub)
provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

# 1. Reference Your Existing Multi-Region Primary KMS Key (From Scenario 105)
data "aws_kms_key" "primary_global_key" {
  key_id = "alias/enterprise-global-sync-key"
}

# 2. Deploy the Synchronized Cryptographic Multi-Region Replica Key (Oregon)
# (This step mirrors the primary key material natively inside your backup region)
resource "aws_kms_replica_key" "oregon_replica_key" {
  provider                = aws.west # CROSS-REGION BINDING: Force compile inside us-west-2
  description             = "Synchronized hardware-backed replica key mirror protecting West Coast DR assets"
  deletion_window_in_days = 7
  
  # BINDING CORRIDOR: Links this replica straight to the primary key material envelope root
  primary_key_arn         = data.aws_kms_key.primary_global_key.arn

  tags = {
    Layer      = "Global-Cryptographic-Mesh-Replica"
    SavedAsset = "True"
  }
}

# 3. Establish the Friendly Alias Mapping Natively Inside the Secondary Region
resource "aws_kms_alias" "replica_key_alias" {
  provider      = aws.west
  name          = "alias/enterprise-global-sync-key" # Maintains identical naming patterns across regions
  target_key_id = aws_kms_replica_key.oregon_replica_key.key_id
}

# 4. Program a Dedicated KMS Grant Authorizing the Local DR EC2 Auto Scaling Daemons
resource "aws_kms_grant" "dr_compute_grant" {
  provider          = aws.west
  name              = "dr-autoscaling-compute-grant"
  key_id            = aws_kms_replica_key.oregon_replica_key.arn
  grantee_principal = "arn:aws:iam::123456789012:role/aws-service-role/://amazonaws.com"

  operations = [
    "Encrypt",
    "Decrypt",
    "ReEncryptFrom",
    "ReEncryptTo",
    "GenerateDataKey",
    "GenerateDataKeyWithoutPlaintext",
    "DescribeKey"
  ]
}
