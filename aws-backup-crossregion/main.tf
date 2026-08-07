# =====================================================================
# CERTIFICATION SCENARIO 11: AUTOMATED CROSS-REGION DATA VAULTING
# COMPONENT: AWS BACKUP SCHEDULER ENFORCING DISASTER RECOVERY COMPLIANCE
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Provision the Target Backup Storage Vault in the Primary Region (Virginia)
resource "aws_backup_vault" "primary_vault" {
  name        = "primary-datacenter-backup-vault"
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/mock-key-east" # References your secure KMS block locks
}

# 2. Reference the Existing Destination Vault in the Backup Region (Oregon)
# In production, this resource matches a vault deployed in your us-west-2 terraform modules
data "aws_backup_vault" "destination_west_vault" {
  name = "disaster-recovery-backup-vault-west"
}

# 3. Architect the Enterprise Automated Data Protection Backup Plan
resource "aws_backup_plan" "enterprise_dr_plan" {
  name = "enterprise-database-dr-compliance-plan"

  rule {
    rule_name         = "daily-backup-with-cross-region-replication"
    target_vault_name = aws_backup_vault.primary_vault.name
    schedule          = "cron(0 12 * * ? *)" # Triggers a snapshot automatically every single day at 12:00 PM UTC

    lifecycle {
      delete_after = 30 # Retain backups for 30 days before automatic cryptographic shredding
    }

    # CROSS-REGION DISASTER RECOVERY INTERFACE MAPPING
    # Automatically copies the daily snapshot across the country to Oregon
    copy_action {
      destination_vault_arn = "arn:aws:backup:us-west-2:123456789012:backup-vault:disaster-recovery-backup-vault-west"

      lifecycle {
        delete_after = 14 # Keep the secondary offsite copy for 14 days to minimize regional retention costs
      }
    }
  }

  tags = {
    Compliance = "RPO-24HR-Enforced"
    SavedAsset = "True"
  }
}

# 4. Bind Your Production DynamoDB Table Securely to the Backup Execution Plan
resource "aws_backup_selection" "dynamodb_data_selection" {
  iam_role_arn = "arn:aws:iam::123456789012:role/service-role/AWSBackupDefaultServiceRole"
  name         = "production-dynamodb-table-selection"
  plan_id      = aws_backup_plan.enterprise_dr_plan.id

  # Targeted Resource Assignment: Injects your global ledger table into the backup scheduler
  resources = [
    "arn:aws:dynamodb:us-east-1:123456789012:table/enterprise-global-user-ledger" # Binds to your Phase 5 Global Table!
  ]
}
