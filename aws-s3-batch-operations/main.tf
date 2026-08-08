# =====================================================================
# CERTIFICATION SCENARIO 45: MULTI-MILLION OBJECT DATA REMEDIATION
# COMPONENT: S3 BATCH OPERATIONS & INVENTORY LEDGER AGGREGATION
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Reference Your Primary Legacy S3 Storage Bucket (Housing unencrypted data)
resource "aws_s3_bucket" "legacy_data_bucket" {
  bucket        = "enterprise-historical-financial-records-2026"
  force_destroy = false
}

# 2. Deploy a Staging S3 Bucket to Hold the Automated Inventory Reports
resource "aws_s3_bucket" "inventory_report_vault" {
  bucket        = "enterprise-s3-inventory-reports-destination"
  force_destroy = true
}

# 3. Architect the S3 Bucket Inventory Engine (Compiles the bulk file manifest)
resource "aws_s3_bucket_inventory" "bulk_manifest_generator" {
  bucket                  = aws_s3_bucket.legacy_data_bucket.id
  name                    = "WeeklyObjectInventoryManifest"
  included_object_versions = "Current"

  schedule {
    frequency = "Weekly"
  }

  optional_fields = ["Size", "LastModifiedDate", "StorageClass", "ETag"]

  destination {
    bucket {
      format     = "CSV"
      bucket_arn = aws_s3_bucket.inventory_report_vault.arn
      prefix     = "inventory-manifests"
      
      encryption {
        sse_s3 {} # Secures the report sheets at rest natively
      }
    }
  }
}

# 4. Create the Secure IAM Execution Role for S3 Batch Operations
resource "aws_iam_role" "s3_batch_execution_role" {
  name = "DataCenter-S3-BatchOperations-Runner"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege batch tokens to allow bulk copy/encrypt actions
resource "aws_iam_role_policy" "s3_batch_remediation_policy" {
  name = "S3Batch-Bulk-Remediation-Access"
  role = aws_iam_role.s3_batch_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:InitiateReplication"
        ]
        Resource = [
          "${aws_s3_bucket.legacy_data_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = [
          "${aws_s3_bucket.inventory_report_vault.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
          "kms:Encrypt"
        ]
        Resource = ["arn:aws:kms:us-east-1:123456789012:key/mock-database-kms-key"] # Phase 3 Master DRM Key
      }
    ]
  })
}
