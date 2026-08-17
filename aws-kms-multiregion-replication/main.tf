# =====================================================================
# CERTIFICATION SCENARIO 105: GLOBAL CRYPTOGRAPHIC MESH ARCHITECTURES
# COMPONENT: KMS MULTI-REGION PRIMARIES SYNCHRONIZING REPLICA KEYS
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

# 1. Architect the Authoritative Master Multi-Region Primary KMS Key (Virginia)
resource "aws_kms_key" "global_master_key" {
  description             = "Central primary multi-region key managing cross-region data plain ciphers"
  deletion_window_in_days = 30
  enable_key_rotation     = true # Mandates native, hands-free 365-day automated cryptographic rotation

  # CRITICAL STRUCTURAL GUARDRAIL: Commands HSM modules to permit cross-region replication
  multi_region            = true 

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootKeyManagement"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::123456789012:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = {
    Layer      = "Global-Cryptographic-Mesh"
    SavedAsset = "True"
  }
}

resource "aws_kms_alias" "primary_alias" {
  name          = "alias/enterprise-global-sync-key"
  target_key_id = aws_kms_key.global_master_key.key_id
}

# 2. Deploy the Synchronized Cryptographic Multi-Region Replica Key (Oregon)
# (This step mirrors the primary key material natively inside your backup region)
resource "aws_kms_replica_key" "west_coast_replica" {
  provider                = aws.west # CROSS-REGION BINDING: Force compile inside us-west-2
  description             = "Synchronized hardware-backed replica key mirror protecting West Coast assets"
  deletion_window_in_days = 7
  
  # BINDING CORRIDOR: Links this replica straight to the primary key material envelope root
  primary_key_arn         = aws_kms_key.global_master_key.arn
}

resource "aws_kms_alias" "replica_alias" {
  provider      = aws.west
  name          = "alias/enterprise-global-sync-key" # Keeps identical friendly naming structures across regions
  target_key_id = aws_kms_replica_key.west_coast_replica.key_id
}
