# =====================================================================
# CERTIFICATION SCENARIO 89: VULNERABILITY GOVERNANCE PIPELINES
# COMPONENT: SSM RESOURCE DATA SYNC POOLING MULTI-ACCOUNT PATCH STATES
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

# 1. CENTRAL ACCOUNT BLUEPRINT: Provision the Security Dashboard Ingestion Vault
# (This resource is deployed directly inside your Central Security Account)
resource "aws_s3_bucket" "central_patch_dashboard_vault" {
  bucket        = "enterprise-centralized-patch-compliance-sync-2026"
  force_destroy = false
}

# Enforce a strict bucket policy authorizing the SSM service globally to write logs
resource "aws_s3_bucket_policy" "allow_global_ssm_patch_sync" {
  bucket = aws_s3_bucket.central_patch_dashboard_vault.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SSMPatchSyncBucketDeliveryCheck"
        Effect = "Allow"
        Principal = { Service = "://amazonaws.com" }
        Action   = "s3:GetBucketLocation"
        Resource = "arn:aws:s3:::enterprise-centralized-patch-compliance-sync-2026"
      },
      {
        Sid    = "SSMPatchSyncBucketDeliveryWrite"
        Effect = "Allow"
        Principal = { Service = "://amazonaws.com" }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::enterprise-centralized-patch-compliance-sync-2026/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# 2. SPOKE ACCOUNT BLUEPRINT: Multi-Account Patch Compliance Resource Data Sync
# (This explicit resource block is what you deploy inside EACH child account
# to route its patch and inventory states straight up to the central vault)
resource "aws_ssm_resource_data_sync" "patch_compliance_sync" {
  name = "enterprise-crossaccount-patch-compliance-sync"

  s3_destination {
    bucket_name = "enterprise-centralized-patch-compliance-sync-2026" # Targets the master central vault
    region      = "us-east-1"
    sync_format = "JsonSerDe"
    prefix      = "spoke-account-patch-telemetry"
  }
}
