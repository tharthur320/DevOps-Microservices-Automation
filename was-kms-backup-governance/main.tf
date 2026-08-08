# =====================================================================
# CERTIFICATION SCENARIO 44: CRYPTOGRAPHIC BACKUP PROTECTION
# COMPONENT: HARDENED KMS KEY POLICIES BLOCKING DESTRUCTIVE DELETIONS
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Fetch Local Structural Account Metrics Natively
data "aws_caller_identity" "current" {}

# 2. Architect the Hardened Asymmetric KMS Key Policy Document
data "aws_iam_policy_document" "immutable_key_policy" {
  statement {
    sid    = "EnableRootAccountManagement"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowBackupServicesToEncryptAndDecrypt"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["://amazonaws.com"]
    }
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt",
      "kms:Encrypt"
    ]
    resources = ["*"]
  }

  # HARDENED GOVERNANCE BOUNDARY: Explicitly block ANY corporate operational role
  # from triggering key deletion routines to protect background data vaults
  statement {
    sid    = "DenyDestructiveKeyDeletionActions"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"] # Applies as a universal safety gate across the account
    }
    actions = [
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
      "kms:DeleteCustomKeyStore"
    ]
    resources = ["*"]
    
    # Exception: Prevent this policy from locking out your master multi-party organizational accounts
    condition {
      string_not_like = {
        "aws:PrincipalArn" = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/Enterprise-Central-Security-BreakGlass"
        ]
      }
    }
  }
}

# 3. Deploy the Hardened AWS KMS Customer-Managed Key
resource "aws_kms_key" "immutable_backup_key" {
  description             = "Cryptographic lock safeguarding production backup archives from deletion attacks"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  # Inject your verified, zero-trust policy document directly into the resource
  policy                  = data_aws_iam_policy_document.immutable_key_policy.json

  tags = {
    Layer      = "Cryptographic-Data-Guardrail"
    SavedAsset = "True"
  }
}
