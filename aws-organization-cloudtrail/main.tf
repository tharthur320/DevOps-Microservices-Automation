# =====================================================================
# CERTIFICATION SCENARIO 87: MULTI-ACCOUNT FORENSIC COMPLIANCE
# COMPONENT: AWS ORGANIZATIONAL CLOUDTRAIL WITH HARDENED KMS LOCKS
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
  region = "us-east-1" # Deployed exclusively inside your AWS Organizations Management Account
}

# 1. Provision the Centralized Security Audit S3 Storage Bucket Vault
resource "aws_s3_bucket" "central_trail_vault" {
  bucket        = "enterprise-organization-cloudtrail-audit-vault-2026"
  force_destroy = false # Strict guardrail: prevents code-driven demolition of compliance data
}

# Enforce explicit bucket access rules authorizing the global CloudTrail engine to write data
resource "aws_s3_bucket_policy" "cloudtrail_write_policy" {
  bucket = aws_s3_bucket.central_trail_vault.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = { Service = "://amazonaws.com" }
        Action   = "s3:GetBucketLocation"
        Resource = aws_s3_bucket.central_trail_vault.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = { Service = "://amazonaws.com" }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.central_trail_vault.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# 2. Deploy a Custom AWS KMS Master Key with Hardened CloudTrail Permissions
resource "aws_kms_key" "cloudtrail_encryption_key" {
  description             = "Cryptographic Master Key locking organization-wide log files at rest"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootManagement"
        Effect = "Allow"
        Principal = { AWS = "arn:aws:iam::123456789012:root" } # Management Account Root
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudTrailToEncrypt"
        Effect = "Allow"
        Principal = { Service = "://amazonaws.com" }
        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}

# 3. Architect the Enterprise Organization Multi-Region CloudTrail Subsystem
resource "aws_cloudtrail" "organization_global_trail" {
  name                          = "enterprise-global-governance-audit-trail"
  s3_bucket_name                = aws_s3_bucket.central_trail_vault.id
  kms_key_id                    = aws_kms_key.cloudtrail_encryption_key.arn
  include_global_service_events = true
  
  # IRONCLAD GOVERNANCE POLICIES: Force universal coverage across the corporate grid
  is_multi_region_trail         = true # Collect logs from all geographical regions worldwide
  is_organization_trail         = true # Automatically enroll all child sub-accounts into this trail
  enable_log_file_validation    = true # Generates cryptographic signatures to prove logs haven't been tampered with

  depends_on = [aws_s3_bucket_policy.cloudtrail_write_policy]

  tags = {
    Layer      = "Organizational-Compliance-Perimeter"
    SavedAsset = "True"
  }
}
