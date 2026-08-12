# =====================================================================
# CERTIFICATION SCENARIO 71: STREAMING AUDITING & LOG SANITIZATION
# COMPONENT: KINESIS FIREHOSE DATA PROCESSING VIA LAMBDA TRANSFORMS
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

# 1. Reference Your Central Encrypted S3 Compliance Storage Bucket Vault
data "aws_s3_bucket" "logging_destination" {
  name = "enterprise-centralized-siem-logs-2026" # Reuses your Scenario 10 SIEM log bucket!
}

# 2. Reference Your Reusable Private Compute Function (AWS Lambda Sanitize Script)
data "aws_lambda_function" "pii_redactor" {
  function_name = "Enterprise-Core-Serverless-TelemetryProcessor" # Existing Scenario 52 worker role
}

# 3. Create the Secure IAM Role Allowing Firehose to Invoke Lambda and Write to S3
resource "aws_iam_role" "firehose_processing_role" {
  name = "DataCenter-Firehose-InFlightProcessor-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege invocation tokens to the streaming engine role
resource "aws_iam_role_policy" "firehose_processing_privileges" {
  name = "Firehose-Data-Transformation-Access"
  role = aws_iam_role.firehose_processing_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "lambda:GetFunctionConfiguration"
        ]
        Resource = ["${data.aws_lambda_function.pii_redactor.arn}:*"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          data.aws_s3_bucket.logging_destination.arn,
          "${data.aws_s3_bucket.logging_destination.arn}/*"
        ]
      }
    ]
  })
}

# 4. Architect the Hardened In-Flight Kinesis Firehose Delivery Stream
resource "aws_kinesis_firehose_delivery_stream" "sanitized_stream" {
  name        = "aws-waf-logs-pii-scrubber" # Prefix groups stream records for enterprise WAF/SIEM rules
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_processing_role.arn
    bucket_arn = data.aws_s3_bucket.logging_destination.arn

    buffer_size        = 5   # Wait until 5 Megabytes of logs pool in memory...
    buffer_interval    = 60  # ...or wait exactly 60 seconds before executing data transformations

    # IN-FLIGHT PROCESSING AND SANITIZATION ENGINE LAYER
    # Intercepts raw stream payloads and routes them to your serverless code gates
    processing_configuration {
      enabled = true

      processors {
        type = "Lambda"

        parameter {
          name  = "LambdaArn"
          value = "${data.aws_lambda_function.pii_redactor.arn}:$LATEST"
        }
        parameter {
          name  = "BufferSizeInMBs"
          value = "3"
        }
        parameter {
          name  = "BufferIntervalInSeconds"
          value = "60"
        }
      }
    }
  }
}
