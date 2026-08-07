# =====================================================================
# CERTIFICATION SCENARIO 25: AUTOMATED INCIDENT REMEDIATION
# COMPONENT: SECURITY HUB & SSM AUTOMATION FOR SELF-HEALING STORAGE
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Activate AWS Security Hub to Centralize Compliance Audits
resource "aws_securityhub_account" "central_security_hub" {}

# 2. Architect the EventBridge Security Rule Intercepting Compliance Failures
resource "aws_cloudwatch_event_rule" "security_hub_remediation_rule" {
  name        = "securityhub-s3-public-access-remediation"
  description = "Intercepts S3 public access violations from Security Hub and triggers self-healing"

  # Event Pattern: Filters explicitly for Security Hub findings flagged as non-compliant or failed
  event_pattern = jsonencode({
    "source": ["aws.securityhub"],
    "detail-type": ["Security Hub Findings - Imported"],
    "detail": {
      "findings": {
        "Compliance": {
          "Status": ["FAILED"]
        },
        "GeneratorId": ["arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v1.2.0/rule/2.3"] # CIS Benchmark for S3 Public Access Block
      }
    }
  })

  depends_on = [aws_securityhub_account.central_security_hub]
}

# 3. Create the Secure IAM Role Allowing EventBridge to Invoke SSM Automation
resource "aws_iam_role" "eventbridge_ssm_role" {
  name = "DataCenter-EventBridge-SSM-Remediation-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind an IAM policy allowing EventBridge to execute the AWS Systems Manager Automation document
resource "aws_iam_role_policy" "eventbridge_ssm_execution" {
  name = "EventBridge-SSM-Execution-Access"
  role = aws_iam_role.eventbridge_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:StartAutomationExecution"
      ],
      Resource = "arn:aws:ssm:us-east-1::automation-definition/AWS-ConfigureS3BucketPublicAccessBlock:*"
    }]
  })
}

# 4. Bind EventBridge Directly to the Self-Healing SSM Automation Target
resource "aws_cloudwatch_event_target" "ssm_remediation_target" {
  rule      = aws_cloudwatch_event_rule.security_hub_remediation_rule.name
  target_id = "TriggerS3PublicAccessBlock"
  arn       = "arn:aws:ssm:us-east-1::automation-definition/AWS-ConfigureS3BucketPublicAccessBlock"
  role_arn  = aws_iam_role.eventbridge_ssm_role.arn

  # Input Transformer: Extracts the specific non-compliant S3 Bucket Name from the JSON finding payload
  input_transformer {
    input_paths = {
      "BucketName" = "$.detail.findings[0].Resources[0].Id"
    }
    input_template = "{\"BucketName\": [<BucketName>], \"RestrictPublicBuckets\": [\"true\"], \"BlockPublicAcls\": [\"true\"], \"BlockPublicPolicy\": [\"true\"], \"IgnorePublicAcls\": [\"true\"]}"
  }
}
