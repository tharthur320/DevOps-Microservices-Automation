# =====================================================================
# CERTIFICATION SCENARIO 122: MULTI-ACCOUNT PARAMETER GOVERNANCE
# COMPONENT: SECURESTRING PARAMETERS REPLICATING VIA CROSS-ACCOUNT KMS
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
  region = "us-east-1" # Deployed inside your Central DevOps Tooling Account (123456789012)
}

# 1. Provision the Dedicated Multi-Account Secure Parameter KMS Key
resource "aws_kms_key" "parameter_sharing_key" {
  description             = "Master key encrypting secure parameter tokens for cross-account extraction"
  deletion_window_in_days = 30
  enable_key_rotation     = true # Mandates native hands-free 365-day automated key rotation

  # 2. INTRODUCE THE MULTI-ACCOUNT IDENTITY TRUST ENVELOPE POLICY
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLocalRootAndAdministrativeManagement"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::123456789012:root" # Retains management rights inside home Tooling account
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AuthorizeProductionAccountDecryptionTokens"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::888888888888:root" # Trust corridor to the remote Production account
        }
        # Restricts external accounts strictly to decryption handshakes for parameter readings
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Layer      = "MultiAccount-Secrets-Mesh"
    SavedAsset = "True"
  }
}

# 3. Architect the SecureString Parameter Store Configuration Asset
resource "aws_ssm_parameter" "shared_database_url" {
  name        = "/enterprise/production/database_url"
  description = "Production master database endpoint connection string shared cross-account"
  type        = "SecureString"
  value       = "postgresql://dbadmin:HardenedProdClusterPass2026@enterprise-primary-cluster.corp.internal:5432/production_core"
  key_id      = aws_kms_key.parameter_sharing_key.arn # Cryptographically binds parameter to the shared key

  tags = {
    Compliance = "Encrypted-CrossAccount-Parameter"
  }
}
