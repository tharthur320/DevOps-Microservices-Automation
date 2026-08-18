# =====================================================================
# CERTIFICATION SCENARIO 181: IMMUTABLE DATA PROTECTION CORES
# COMPONENT: ACCOUNT-WIDE SWITCHES ENFORCING MANDATORY EBS ENCRYPTION
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

# 1. Reference Your Central Cross-Region Cryptographic Master KMS Key
data "aws_kms_key" "master_crypto_key" {
  key_id = "alias/enterprise-global-sync-key" # Reuses your secure Scenario 105 key ciphers
}

# 2. Activate the Ironclad Regional EBS Encryption by Default Safeguard
# This global account toggle intercepts all block storage calls at the API layer.
resource "aws_ebs_encryption_by_default" "enforce_encryption" {
  enabled = true
}

# 3. Bind Your Central Customer-Managed KMS Key as the Regional Encryption Root
# This step forces all future un-targeted volume requests to compile under this key vault.
resource "aws_ebs_default_kms_key" "default_kms_root" {
  key_arn = data.aws_kms_key.master_crypto_key.arn

  # Explicit dependency ensures the account-wide default switch is active before setting the root key
  depends_on = [aws_ebs_encryption_by_default.enforce_encryption]
}

# 4. Deploy a Regional Compliance Auditor Rule to Double-Check State Health
resource "aws_config_config_rule" "ebs_default_encryption_check" {
  name        = "account-ebs-encryption-by-default-audit"
  description = "Verifies that account-wide mandatory EBS encryption-by-default switches remain activated"

  source {
    owner             = "AWS"
    source_identifier = "EBS_ENCRYPTION_BY_DEFAULT_ENABLED"
  }

  depends_on = [resource.aws_ebs_default_kms_key.default_kms_root]
}
