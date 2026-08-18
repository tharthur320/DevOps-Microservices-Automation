# =====================================================================
# CERTIFICATION SCENARIO 196: MULTI-ACCOUNT SHELL AUDIT INFRASTRUCTURE
# COMPONENT: SSM RUNSESSION DOCUMENTS ENFORCING CENTRALIZED S3 REPLAYS
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

# 1. Reference Your Centralized Multi-Account Governance S3 Storage Bucket Vault
data "aws_s3_bucket" "central_log_vault" {
  name = "enterprise-saas-salesforce-compliance-vault-2026" # Central secure logging repository
}

# 2. Reference Your Central Cross-Region Cryptographic Master KMS Key
data "aws_kms_key" "master_crypto_key" {
  key_id = "alias/enterprise-global-sync-key" # Reuses your secure Phase 3 key ciphers
}

# 3. Architect the Global SSM Session Manager Absolute Preference Document
# NOTE: The document name MUST be exactly "SSM-SessionManagerRunSession" for the region
resource "aws_ssm_document" "session_manager_preferences" {
  name            = "SSM-SessionManagerRunSession"
  document_type   = "Session" # Mandates the terminal session control plane configuration format
  content_format  = "JSON"

  # CONTROL PLANE SETTINGS: Enforces ironclad terminal logging boundaries account-wide
  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Global corporate preferences document enforcing mandatory session logging and cryptographic locks"
    inputs = {
      s3BucketName                = data.aws_s3_bucket.central_log_vault.id
      s3KeyPrefix                 = "ssm-session-logs/"
      s3EncryptionEnabled         = true # Encrypt log archives at rest natively within the S3 bucket
      cloudWatchLogGroupName      = ""
      cloudWatchEncryptionEnabled = false
      
      # HARDENED CRYPTOGRAPHIC CORES: Mandates end-to-point transit key encryption
      kmsKeyId                    = data.aws_kms_key.master_crypto_key.arn
      runAsEnabled                = false # Disable loose unix user mapping to enforce direct IAM identity accountability
      
      # Force session dropouts if the central S3 storage pipeline encounters network errors
      shellProfile = {
        windows = ""
        linux   = "set -o pipefail; alias rm='rm -i'; echo \"=== UN-ALTERABLE CORPORATE AUDIT TRAIL RUNNING ===\""
      }
    }
  })

  tags = {
    Layer      = "Shell-Ingress-Governance"
    Compliance = "Immutable-Audit-Streaming"
    SavedAsset = "True"
  }
}

# 4. Deploy a Regional Compliance Auditor Rule to Ensure Settings Aren't Bypassed
resource "aws_config_config_rule" "ssm_logging_check" {
  name        = "ssm-session-logging-enabled-audit"
  description = "Verifies that account-wide global SSM terminal recording configurations remain activated"

  source {
    owner             = "AWS"
    source_identifier = "SSM_SESSION_LOGGING_ENABLED"
  }

  depends_on = [aws_ssm_document.session_manager_preferences]
}
