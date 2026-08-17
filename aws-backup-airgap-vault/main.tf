# =====================================================================
# CERTIFICATION SCENARIO 109: AIR-GAPPED BUSINESS CONTINUITY ARCHITECTURES
# COMPONENT: AWS BACKUP MECHANISMS ENFORCING CROSS-ACCOUNT REPLICATION
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
  region = "us-east-1" # Deployed inside your Central Production Hosting Account
}

# 1. Reference Your Central Cross-Region Cryptographic Master KMS Key
data "aws_kms_key" "backup_encryption_key" {
  key_id = "alias/enterprise-global-core-key" # Reuses your secure Phase 3 key ciphers
}

# 2. Reference the Secure S3 Target Storage Bucket Vault (From Scenario 66)
data "aws_s3_bucket" "production_data_vault" {
  name = "enterprise-core-production-confidential-data-2026"
}

# 3. Provision the Local Encrypted Backup Vault Container
resource "aws_backup_vault" "local_vault" {
  name        = "production-core-backup-vault"
  kms_key_arn = data.aws_kms_key.backup_encryption_key.arn

  tags = {
    Layer      = "Local-Recovery-Vault"
    SavedAsset = "True"
  }
}

# 4. Architect the Autonomous Cross-Account S3 Backup Pipeline
resource "aws_backup_plan" "airgap_backup_plan" {
  name = "enterprise-ransomware-protection-plan"

  rule {
    rule_name         = "daily-s3-immutable-backup-rule"
    target_vault_name = aws_backup_vault.local_vault.name
    schedule          = "cron(0 12 * * ? *)" # Trigger the backup process automatically every single day at 12:00 PM UTC

    lifecycle {
      delete_after = 30 # Retain local backups for exactly 30 days before cleanups trigger
    }

    # CROSS-ACCOUNT AIR-GAP DEPLOYMENT CORRIDOR
    # Automatically routes a twin copy of the snapshot straight to your isolated DR account vault
    copy_action {
      destination_vault_arn = "arn:aws:backup:us-east-1:999999999999:backup-vault:enterprise-isolated-dr-vault" # Remote DR Account ID

      lifecycle {
        delete_after = 90 # Maintain long-term archival data inside the remote account for 90 days
      }
    }
  }
}

# 5. Connect Your Target Production Data Store Directly to the Backup Scheduler
resource "aws_backup_selection" "s3_backup_binding" {
  iam_role_arn = "arn:aws:iam::123456789012:role/service-role/AWSBackupDefaultServiceRole"
  name         = "production-s3-data-selection"
  plan_id      = aws_backup_plan.airgap_backup_plan.id

  # Ingests and binds your Scenario 66 data bucket natively into the backup plane selection
  resources = [
    data.aws_s3_bucket.production_data_vault.arn
  ]
}
