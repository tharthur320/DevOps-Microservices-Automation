# =====================================================================
# CERTIFICATION SCENARIO 117: MULTI-ACCOUNT CRYPTOGRAPHIC ISOLATION
# COMPONENT: KMS POLICIES DELEGATING CROSS-ACCOUNT ACCESS TIERS
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

# 1. Provision the Multi-Account Shareable Customer-Managed Master KMS Key
resource "aws_kms_key" "cross_account_shared_key" {
  description             = "Central master image key authorizing cross-account production decryption pipelines"
  deletion_window_in_days = 30
  enable_key_rotation     = true # Enforces ironclad automatic 365-day key rotation

  # 2. ARCHITECT THE MULTI-ACCOUNT CROSS-ACCOUNT IDENTITY POLICY
  # Programs explicit boundaries split between local admin rights and remote crypto tokens
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableLocalRootAndAdministrativeManagement"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::123456789012:root" # Retains 100% administrative keys in the home Tooling account
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AuthorizeProductionAccountCrossAccountUsage"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::888888888888:root" # Establishes the trust corridor to the remote Production account
        }
        # Restricts external privileges strictly to data plane execution and deployment ciphers
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowProductionToCreateGrantsForAutoScaling"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::888888888888:root"
        }
        # EXAM CORE DEFINITION: Production MUST be allowed to delegate tokens via Grants to ASG daemons
        Action = [
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" = "true" # Restricts external grants strictly to native AWS automated services
          }
        }
      }
    ]
  })

  tags = {
    Layer      = "MultiAccount-Cryptographic-Bridge"
    SavedAsset = "True"
  }
}

resource "aws_kms_alias" "shared_key_alias" {
  name          = "alias/enterprise-crossaccount-shared-key"
  target_key_id = aws_kms_key.cross_account_shared_key.key_id
}
