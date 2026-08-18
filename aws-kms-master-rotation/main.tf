# =====================================================================
# CERTIFICATION SCENARIO 200: THE ULTIMATE ROOT SECURITY COMPONENT
# COMPONENT: DYNAMIC MULTI-ACCOUNT ORGANIZATIONAL KEY CONTROL PLANES
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
  region = "us-east-1" # Authoritative deployment plane inside your Master Account (123456789012)
}

# 1. Provision the Ultimate Multi-Account Organizational Root KMS Key
resource "aws_kms_key" "master_organizational_key" {
  description             = "Authoritative corporate master key protecting multi-account global application tiers"
  deletion_window_in_days = 30
  
  # MANDATORY HARDWARE LIFECYCLE CONTROLS
  enable_key_rotation     = true # Forces native 365-day automated key material rotation at rest
  multi_region            = true # Permits seamless architectural replication to backup DR locations

  # 2. ARCHITECT THE ENTERPRISE COHESIVE DECOUPLED KEY POLICY MATRIX
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecureLocalRootAndAdministrativeManagement"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::123456789012:root" # Retains total management tokens inside home account
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AutomateDynamicIngressForEntireOrganizationTree"
        Effect = "Allow"
        Principal = {
          AWS = "*" # Wildcard principal is safely and rigidly fenced by our condition attributes below
        }
        # Grant standard data plane encryption/decryption keys to your global application tiers
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"

        # 3. IRONCLAD MULTI-TENANT CONTAINER GUARDRAILS
        # Bypasses hardcoded child account IDs, natively trusting your entire organization footprint
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID" = "o-xxxxxxxxxx" # Injected dynamically via your corporate organization tokens
          }
        }
      },
      {
        Sid    = "AuthorizeCloudTrailAndConfigAuditVisibility"
        Effect = "Allow"
        Principal = {
          Service = [
            "://amazonaws.com",
            "://amazonaws.com"
          ]
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Layer      = "Root-Cryptographic-Authority"
    Compliance = "Dynamic-Org-Agility"
    SavedAsset = "True"
  }
}

# 4. Establish the Authoritative Master Cryptographic Alias Mapping
resource "aws_kms_alias" "master_root_alias" {
  name          = "alias/enterprise-organizational-root-key"
  target_key_id = aws_kms_key.master_organizational_key.key_id
}

# 5. Output the Authoritative Root Key Identification String for System Integration
output "master_organizational_key_arn" {
  value       = aws_kms_key.master_organizational_key.arn
  description = "The golden master key ARN used to anchor 100% of global data center storage encryptions"
}
