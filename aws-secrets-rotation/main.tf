# =====================================================================
# CERTIFICATION SCENARIO 34: SECURE CREDENTIAL LIFECYCLE MANAGEMENT
# COMPONENT: SECRETS MANAGER AUTOMATED DATABASE PASSWORDS ROTATIONS
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Provision the Hardened Secrets Manager Secret Storage Vault
resource "aws_secretsmanager_secret" "database_secret" {
  name        = "production-core-rds-credentials"
  description = "Hardware-secured container holding master database connection keys"

  # Encryption: Ties database secrets straight to your Phase 3 custom KMS master keys!
  kms_key_id  = "arn:aws:kms:us-east-1:123456789012:key/mock-database-kms-key"

  tags = {
    Layer      = "Credential-Vault"
    SavedAsset = "True"
  }
}

# 2. Architect the Automated Secret Rotation Policy Schedule Controller
resource "aws_secretsmanager_secret_rotation" "password_rotation_policy" {
  secret_id           = aws_secretsmanager_secret.database_secret.id
  rotation_lambda_arn = aws_lambda_function.secrets_rotation_worker.arn

  # FINANCIAL COMPLIANCE BOUNDARY: Force automated password updates every 30 days
  rotation_rules {
    automatically_after_days = 30
  }
}

# 3. Deploy the Serverless Secrets Rotation Execution Function (AWS Lambda)
resource "aws_lambda_function" "secrets_rotation_worker" {
  function_name = "Enterprise-Core-DatabaseSecrets-Rotator"
  role          = aws_iam_role.rotation_exec_role.arn
  handler       = "index.handler"
  runtime       = "python3.11" # Native Python engine ideal for cryptographic database operations

  # Reference a pre-compiled official AWS relational database rotation script blueprint
  filename      = "mock-rotation-script.zip" 
}

# 4. Create the Secure IAM Execution Role for the Rotation Automation Engine
resource "aws_iam_role" "rotation_exec_role" {
  name = "DataCenter-SecretsManager-Rotation-Runner"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind an IAM policy allowing the Lambda engine to modify secrets and alter RDS endpoints
resource "aws_iam_role_policy" "rotation_privileges_policy" {
  name = "SecretsManager-Database-Rotation-Privileges"
  role = aws_iam_role.rotation_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = aws_secretsmanager_secret.database_secret.arn
      },
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:ModifyDBInstance"
        ]
        Resource = "*" # Restrict to specific database instance ARNs in production
      }
    ]
  })
}
