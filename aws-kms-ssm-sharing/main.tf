# =====================================================================
# CERTIFICATION SCENARIO 190: MULTI-ACCOUNT PARAMETER GOVERNANCE
# COMPONENT: KMS KEY POLICIES UNLOCKING CROSS-ACCOUNT SECURESTRINGS
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
resource "aws_kms_key" "ssm_sharing_key" {
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

resource "aws_kms_alias" "ssm_key_alias" {
  name          = "alias/enterprise-crossaccount-ssm-key"
  target_key_id = aws_kms_key.ssm_sharing_key.key_id
}
