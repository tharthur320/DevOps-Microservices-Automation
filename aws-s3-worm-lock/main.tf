# =====================================================================
# CERTIFICATION SCENARIO 63: IMMUTABLE GOVERNANCE DATA CONTAINMENT
# COMPONENT: S3 OBJECT LOCK COMPLIANCE TIED TO SERVERLESS AUDITING
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

# 1. Provision the Hardened S3 Bucket with Native Object Lock Activated
resource "aws_s3_bucket" "worm_ledger_vault" {
  bucket        = "enterprise-immutable-regulatory-ledgers-2026"
  force_destroy = false # Strict safeguard: prevents accidental code-driven demolition of the bucket

  # Mandates the underlying object lock feature flag at the storage engine layer
  object_lock_enabled = true 
}

# 2. Enforce the Ironclad Compliance Mode Object Lock Rule
resource "aws_s3_bucket_object_lock_configuration" "worm_rule" {
  bucket = aws_s3_bucket.worm_ledger_vault.id

  rule {
    default_retention {
      mode  = "COMPLIANCE" # IRONCLAD: Nobody, including root, can delete data during the retention window
      years = 5
    }
  }
}

# 3. Reference Your Reusable Private Compute Function (AWS Lambda Forensics Script)
data "aws_lambda_function" "forensic_hasher" {
  function_name = "Enterprise-Core-Serverless-TelemetryProcessor" # Existing Scenario 52 worker role
}

# Allow S3 to Invoke the Lambda Function Natively
resource "aws_lambda_permission" "allow_s3_invocation" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.forensic_hasher.function_name
  principal     = "://amazonaws.com"
  source_arn    = aws_s3_bucket.worm_ledger_vault.arn
}

# 4. Architect the S3 Event Notification Trigger Channel
resource "aws_s3_bucket_notification" "bucket_write_trigger" {
  bucket = aws_s3_bucket.worm_ledger_vault.id

  lambda_function {
    lambda_function_arn = data.aws_lambda_function.forensic_hasher.arn
    
    # EVENT TRIGGER: Intercept the exact millisecond any file is uploaded or created
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3_invocation]
}
