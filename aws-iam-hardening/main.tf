# =====================================================================
# PROJECT: ENTERPRISE IDENTITY HARDENING (AWS IAM LEAST PRIVILEGE)
# CRYPTOGRAPHIC POLICIES FOR ENFORCING DATA PROTECTION BOUNDARIES
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Generate a Zero-Trust JSON IAM Policy Document Pattern
data "aws_iam_policy_document" "least_privilege_spec" {
  statement {
    sid    = "EnforceStrictDataReadWrite"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ]

    resources = [
      "arn:aws:s3:::enterprise-confidential-data-vault",
      "arn:aws:s3:::enterprise-confidential-data-vault/*"
    ]
  }

  statement {
    sid    = "DenyCryptographicBypass"
    effect = "Deny"

    actions = [
      "s3:DeleteBucket",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion"
    ]

    resources = [
      "arn:aws:s3:::enterprise-confidential-data-vault",
      "arn:aws:s3:::enterprise-confidential-data-vault/*"
    ]
  }
}

# 2. Compile the Document Into an Active Managed IAM Policy Resource
resource "aws_iam_policy" "hardened_policy" {
  name        = "Enterprise-DataVault-RestrictivePolicy"
  path        = "/"
  description = "Hardened IAM execution boundary enforcing strict Least Privilege access metrics"
  policy      = data_aws_iam_policy_document.least_privilege_spec.json
}

# 3. Architect a Secure Execution Role for Microservice Automation Systems
resource "aws_iam_role" "application_execution_role" {
  name = "Production-Microservice-DataWorker"

  # Establish trust configuration parameter: Only allow ECS container engines to assume this identity
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "://amazonaws.com"
        }
      }
    ]
  })
}

# 4. Bind the Hardened Policy Securely to the Application Execution Role
resource "aws_iam_role_policy_attachment" "role_binding" {
  role       = aws_iam_role.application_execution_role.name
  policy_arn = aws_iam_policy.hardened_policy.arn
}
