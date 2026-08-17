# =====================================================================
# CERTIFICATION SCENARIO 127: MULTI-ACCOUNT DEPLOYMENT DELEGATION
# COMPONENT: KMS KEY POLICIES UNLOCKING CROSS-ACCOUNT ARTIFACT CHAINS
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

# 1. Provision the Multi-Account Master Pipeline Encryption KMS Key
resource "aws_kms_key" "cross_account_pipeline_key" {
  description             = "Central master key encrypting pipeline artifacts for cross-account extraction"
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
        # Restricts external account privileges strictly to data plane artifact reading ciphers
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Layer      = "MultiAccount-Deployment-Bridge"
    SavedAsset = "True"
  }
}

resource "aws_kms_alias" "pipeline_key_alias" {
  name          = "alias/enterprise-crossaccount-pipeline-key"
  target_key_id = aws_kms_key.cross_account_pipeline_key.key_id
}
