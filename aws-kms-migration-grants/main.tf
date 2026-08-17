# =====================================================================
# CERTIFICATION SCENARIO 124: MULTI-ACCOUNT STORAGE TRANSIT CORRIDORS
# COMPONENT: AWS KMS GRANTS DELEGATING CROSS-ACCOUNT MIGRATION RIGHTS
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
  region = "us-east-1" # Deployed inside the source Acquisition Cloud Account (777777777777)
}

# 1. Reference the Local Master Custom Customer-Managed KMS Key (Locking Legacy Snapshots)
data "aws_kms_key" "legacy_snapshot_key" {
  key_id = "alias/acquisition-legacy-core-key"
}

# 2. Architect the Scope-Restricted Programmatic KMS Grant Ingestion Link
# (Delegates secure short-lived decryption tokens to the Production Account Migration Engine)
resource "aws_kms_grant" "migration_transit_grant" {
  name              = "crossaccount-storage-migration-grant"
  key_id            = data.aws_kms_key.legacy_snapshot_key.arn
  
  # GRANTEE IDENTITY MAPPING: Targets the native Server Migration service role inside the target Production Account
  grantee_principal = "arn:aws:iam::888888888888:role/aws-service-role/://amazonaws.com"

  # OPERATIONS WHITELIST: Restrict the grant privileges to the bare minimum actions needed to transfer blocks
  operations = [
    "Decrypt",
    "ReEncryptFrom",
    "ReEncryptTo",
    "DescribeKey"
  ]

  # CRITICAL STRUCTURAL GUARDRAIL: Restricts the cryptographic privilege 
  # strictly to internal automated data transit requests, blocking manual token abuse vectors
  constraints {
    encryption_context_equals = {
      "aws:sms:migrationJobId" = "job-prod-migration-stream-2026" # Context-locked migration pipeline target
    }
  }

  retiring_principal = "arn:aws:iam::888888888888:root" # Authorizes the Production target root to retire the grant on job completion
}
