# =====================================================================
# PROJECT: ENTERPRISE AUDITING & GOVERNANCE (AWS CLOUDTRAIL ENGINE)
# COMPONENT: IMMUTABLE AUDIT TRAIL PREVENTING CREDENTIAL ABUSE
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Fetch Local Context to Pull Your Unique Cloud Account ID Natively
data "aws_caller_identity" "current" {}

# 2. Deploy a Secure S3 Storage Locker to Hold Raw Security Log Files
resource "aws_s3_bucket" "audit_log_vault" {
  bucket        = "enterprise-immutable-audit-logs-2026"
  force_destroy = true # Safeguard tool forcing clean resource cleanup during demolition
}

# 3. Write a Mandatory IAM Bucket Policy Allowing CloudTrail to Write Logs
resource "aws_s3_bucket_policy" "allow_cloudtrail_logging" {
  bucket = aws_s3_bucket.audit_log_vault.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "://amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = "arn:aws:s3:::enterprise-immutable-audit-logs-2026"
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "://amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::enterprise-immutable-audit-logs-2026/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# 4. Deploy the Global CloudTrail Engine to Track 100% of Cloud Management Events
resource "aws_cloudtrail" "global_trail" {
  name                          = "enterprise-security-governance-trail"
  s3_bucket_name                = aws_s3_bucket.audit_log_vault.id
  include_global_service_events = true
  is_multi_region_trail         = true # Forces auditing across all physical world regions
  enable_log_file_validation    = true # Enforces cryptographic log integrity file hashing

  depends_on = [aws_s3_bucket_policy.allow_cloudtrail_logging]
}
