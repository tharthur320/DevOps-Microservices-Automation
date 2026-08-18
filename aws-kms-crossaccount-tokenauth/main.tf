# =====================================================================
# CERTIFICATION SCENARIO 172: MULTI-ACCOUNT DEPLOYMENT DELEGATION
# COMPONENT: KMS KEY POLICIES UNLOCKING CROSS-ACCOUNT TOKEN ACCESS
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

# 1. Provision the Multi-Account Master Token Validation Encryption KMS Key
resource "aws_kms_key" "cross_account_token_key" {
  description             = "Central master key encrypting application authentication tokens for cross-account validation"
  deletion_window_in_days = 30
  enable_key_rotation     = true # Enforces ironclad automatic 365-day key rotation

  # 2. ARCHITECT THE MULTI-ACCOUNT CROSS-ACCOUNT IDENTITY POLICY
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecureLocalRootAndAdministrativeManagement"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::123456789012:root" # Retains full admin rights inside the Tooling account
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AuthorizeProductionAccountCrossAccountDecryption"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::888888888888:root" # Establishes the trust corridor to the Production account root
        }
        # Restricts external account privileges strictly to data plane token reading ciphers
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Layer      = "MultiAccount-Token-Bridge"
    SavedAsset = "True"
  }
}

resource "aws_kms_alias" "token_key_alias" {
  name          = "alias/enterprise-crossaccount-token-key"
  target_key_id = aws_kms_key.cross_account_token_key.key_id
}
