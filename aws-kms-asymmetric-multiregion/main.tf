# =====================================================================
# CERTIFICATION SCENARIO 176: ASYMMETRIC CRYPTOGRAPHIC GOVERNANCE
# COMPONENT: ASYMMETRIC MULTI-REGION KEYS DELEGATING CROSS-ACCOUNT VERIFICATION
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

# 1. Provision the Multi-Account Master Asymmetric Multi-Region KMS Key
resource "aws_kms_key" "asymmetric_global_key" {
  description             = "Central primary multi-region asymmetric key managing cross-account ledger signatures"
  deletion_window_in_days = 30
  
  # ASYMMETRIC SPECIFICATION PARAMETERS
  key_usage                = "SIGN_VERIFY"         # Configures key explicitly for digital signatures
  customer_master_key_spec = "RSA_4096"            # Hardens the envelope with ultra-secure RSA-4096 spec
  multi_region             = true                  # Permits native cross-region replication (Scenario 105)

  # 2. ARCHITECT THE MULTI-ACCOUNT CROSS-ACCOUNT IDENTITY TRUST POLICY
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
        Sid    = "AuthorizeProductionAccountCrossAccountVerification"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::888888888888:root" # Establishes the trust corridor to the Production account root
        }
        # EXAM CORE SPECIFICATION: Production is explicitly restricted from signing, only allowed to verify ciphers
        Action = [
          "kms:Verify",
          "kms:GetPublicKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Layer      = "MultiAccount-Asymmetric-Bridge"
    SavedAsset = "True"
  }
}

resource "aws_kms_alias" "asymmetric_key_alias" {
  name          = "alias/enterprise-global-asymmetric-key"
  target_key_id = aws_kms_key.asymmetric_global_key.key_id
}
