# =====================================================================
# CERTIFICATION SCENARIO 171: AUTOMATED GLOBAL CACHE MANAGEMENT
# COMPONENT: EVENTBRIDGE & LAMBDA TRIGGERING PROGRAMMATIC EDGE EVICTIONS
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

# 1. Reference Your Existing Global Content Ingress Gates (From Scenario 161)
data "aws_cloudfront_distribution" "global_accelerator" {
  id = "EDFST123456789" # Your production distribution tracking ID
}

# 2. Reference Your Central Storage Bucket Vault (From Scenario 109)
data "aws_s3_bucket" "production_assets" {
  name = "enterprise-saas-salesforce-compliance-vault-2026"
}

# 3. Architect the EventBridge Rule Catching Storage Object Mutations
resource "aws_cloudwatch_event_rule" "s3_mutation_monitor" {
  name        = "capture-s3-asset-mutations"
  description = "Intercepts storage bucket object writes to trigger automated edge cache updates"

  event_pattern = jsonencode({
    "source": ["aws.s3"],
    "detail-type": ["Object Created"],
    "detail": {
      "bucket": {
        "name": [data.aws_s3_bucket.production_assets.id]
      }
    }
  })
}

# 4. Create the Secure IAM Execution Role for the Cache Invalidator Engine
resource "aws_iam_role" "cache_janitor_role" {
  name = "DataCenter-Lambda-CacheJanitor-ExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege privileges enabling the engine to invalidate CloudFront paths
resource "aws_iam_role_policy" "cache_janitor_privileges" {
  name = "Lambda-CloudFront-CreateInvalidation-Access"
  role = aws_iam_role.cache_janitor_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation"
        ]
        Resource = data.aws_cloudfront_distribution.global_accelerator.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}

# 5. Deploy the Serverless Cache Janitor Function (AWS Lambda)
resource "aws_lambda_function" "cache_janitor_worker" {
  function_name = "Enterprise-Core-CloudFront-CacheJanitor"
  role          = aws_iam_role.cache_janitor_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "mock-cache-janitor.zip"
  timeout       = 30

  environment {
    variables = {
      CLOUDFRONT_DISTRIBUTION_ID = data.aws_cloudfront_distribution.global_accelerator.id
    }
  }
}

# 6. Bind the Monitoring Gate Directly to Invoke the Lambda Target
resource "aws_cloudwatch_event_target" "bind_cache_janitor_target" {
  rule      = aws_cloudwatch_event_rule.s3_mutation_monitor.name
  target_id = "InvokeCloudFrontCacheJanitor"
  arn       = aws_lambda_function.cache_janitor_worker.arn
}

# Allow EventBridge to Invoke the Lambda Function Natively
resource "aws_lambda_permission" "allow_eventbridge_cache_trigger" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cache_janitor_worker.function_name
  principal     = "://amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_mutation_monitor.arn
}
