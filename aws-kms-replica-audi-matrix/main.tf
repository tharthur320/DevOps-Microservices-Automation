# =====================================================================
# CERTIFICATION SCENARIO 186: GLOBAL CRYPTOGRAPHIC POSTURE GOVERNANCE
# COMPONENT: KMS REPLICA POLICIES TRACKING CROSS-ACCOUNT IDENTITY MATRICES
# =====================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Initialize the Secondary Region Network Provider (Oregon Backup Hub)
provider "aws" {
  region = "us-west-2"
}

# 1. Reference Your Central Multi-Region Primary KMS Key (From Scenario 105)
data "aws_kms_key" "primary_global_key" {
  provider = aws
  key_id   = "alias/enterprise-global-sync-key"
}

# 2. Deploy the Hardened Multi-Region Replica Key equipped with Audit Controls
resource "aws_kms_replica_key" "hardened_oregon_replica" {
  description             = "Synchronized hardware replica key enforcing multi-account access matrix checks"
  deletion_window_in_days = 7
  primary_key_arn         = data.aws_kms_key.primary_global_key.arn

  # 3. INTERCEPT PIPELINE: THE ADVANCED IDENTITY CONDITION MATRIX
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAdministrativeManagement"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::123456789012:root" # Retains 100% administrative keys in the home account
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "EnforceDynamicAccessMatrixCipherTokens"
        Effect = "Allow"
        Principal = {
          AWS = "*" # Wildcard principal is safely and tightly fenced by our condition attributes below
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
        
        # 4. DYNAMIC CROSS-ACCOUNT IDENTITY EVALUATION
        # Validates that the external caller belongs to an approved account AND projects matching tags
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID"       = "o-xxxxxxxxxx"
            "kms:PrincipalTag/Project" = "EnterpriseCoreCommerce"
            "kms:PrincipalTag/Tier"    = "ProductionRecovery"
          }
        }
      }
    ]
  })

  tags = {
    Layer      = "Global-Cryptographic-Mesh-Replica"
    Compliance = "AccessMatrix-Audited"
    SavedAsset = "True"
  }
}

# 5. Establish the Matching Friendly Alias Mapping Natively Inside the Region
resource "aws_kms_alias" "replica_audit_key_alias" {
  name          = "alias/enterprise-global-sync-key" # Maintains identical naming patterns across regions
  target_key_id = aws_kms_replica_key.hardened_oregon_replica.key_id
}
