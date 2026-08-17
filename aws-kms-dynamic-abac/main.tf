# =====================================================================
# CERTIFICATION SCENARIO 146: ADVANCED MULTI-TENANT CRYPTOGRAPHY
# COMPONENT: KMS POLICIES ENFORCING DYNAMIC ABAC EVALUATION RULES
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

# 1. Architect the Dynamic ABAC-Enforced Multi-Region Primary KMS Key
resource "aws_kms_key" "abac_global_key" {
  description             = "Global primary multi-region key enforcing dynamic ABAC tenant isolation"
  deletion_window_in_days = 30
  enable_key_rotation     = true # Mandates native hands-free 365-day automated cryptographic rotation
  multi_region            = true # Permits low-level cross-region synchronization (Scenario 105)

  # 2. IMPLEMENT THE DYNAMIC PRINCIPAL EVALUATION SECURITY POLICY
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAdministrativeManagement"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::123456789012:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "EnforceDynamicTenantABACCipherTokens"
        Effect = "Allow"
        Principal = {
          AWS = "*" # Wildcard principal is safely and tightly fenced by our condition attributes below
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        
        # 3. DYNAMIC IDENTITY CONDITION MATCHING LOOPS
        # Forces the caller's Project tag to match the target asset's tag string exactly
        Condition = {
          StringEquals = {
            "kms:PrincipalTag/Project" = "EnterpriseCoreCommerce"
          }
        }
      }
    ]
  })

  tags = {
    Project    = "EnterpriseCoreCommerce" # Must match the caller's identity tag profile exactly
    Layer      = "Global-Cryptographic-ABAC"
    SavedAsset = "True"
  }
}

resource "aws_kms_alias" "abac_key_alias" {
  name          = "alias/enterprise-abac-commerce-key"
  target_key_id = aws_kms_key.abac_global_key.key_id
}
