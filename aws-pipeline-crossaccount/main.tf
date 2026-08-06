hcl# =====================================================================
# CERTIFICATION SCENARIO 2: MULTI-ACCOUNT PIPELINE ARTIFACT SHARING
# COMPONENT: SECURE ENCRYPTED CROSS-ACCOUNT STORAGE & IDENTITY EXCHANGE
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Provision the Central Pipeline Artifact S3 Storage Locker
resource "aws_s3_bucket" "artifact_store" {
  bucket        = "enterprise-crossaccount-pipeline-artifacts-2026"
  force_destroy = true
}

# 2. Deploy a Custom AWS KMS Cryptographic Master Key for Cross-Account Sharing
resource "aws_kms_key" "pipeline_sharing_key" {
  description             = "KMS Key utilized to encrypt artifacts sent between tool and prod accounts"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

# 3. Write the Cross-Account S3 Bucket Policy
resource "aws_s3_bucket_policy" "share_pipeline_artifacts" {
  bucket = aws_s3_bucket.artifact_store.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountProdAccess"
        Effect = "Allow"
        Principal = {
          # Whitelists the entire physical AWS Production Account number
          AWS = "arn:aws:iam::888888888888:root" 
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::enterprise-crossaccount-pipeline-artifacts-2026",
          "arn:aws:s3:::enterprise-crossaccount-pipeline-artifacts-2026/*"
        ]
      }
    ]
  })
}

# 4. Create the Production Identity Cross-Account Assume Role Trust Boundary
resource "aws_iam_role" "cross_account_pipeline_role" {
  name = "Enterprise-CrossAccount-Pipeline-Deployer"

  # Trust Policy: Explicitly allows the central DevOps Tooling Account to take over this identity
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::111111111111:root" # DevOps Tooling Account ID
        }
      }
    ]
  })
}
