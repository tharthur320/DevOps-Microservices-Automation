# =====================================================================
# CERTIFICATION SCENARIO 68: ZERO-SSH INTERACTIVE SERVER OPERATIONS
# COMPONENT: HARDENED SSM SESSION DOCUMENTS WITH ENFORCED FORENSIC LOGS
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

# 1. Provision an Isolated S3 Storage Vault to Ingest Terminal Keystroke Logs
resource "aws_s3_bucket" "session_log_vault" {
  bucket        = "enterprise-datacenter-ssm-session-keystrokes-2026"
  force_destroy = true
}

# 2. Deploy a Dedicated CloudWatch Log Group for Real-Time Session Auditing
resource "aws_cloudwatch_log_group" "ssm_log_group" {
  name              = "enterprise-ssm-session-forensic-audit"
  retention_in_days = 90
}

# 3. Architect the Enforced Governance Shell Session Control Document
# (This master blueprint forces encryption and logging when an admin connects)
resource "aws_ssm_document" "session_manager_preferences" {
  name            = "SSM-SessionManagerRunShell" # MUST use this exact name to override default shell behaviors
  document_type   = "Session"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Master session manager preferences forcing immutable logging across all servers"
    sessionType   = "Standard_Stream"
    inputs = {
      s3BucketName                = aws_s3_bucket.session_log_vault.id
      s3KeyPrefix                 = "terminal-sessions/"
      s3EncryptionEnabled         = true # Cryptographically secures static log files at rest
      cloudWatchLogGroupName      = aws_cloudwatch_log_group.ssm_log_group.name
      cloudWatchEncryptionEnabled = true
      cloudWatchStreamingEnabled  = true # Streams logs line-by-line in real time to catch shell commands
      runAsEnabled                = false # Blocks developers from arbitrarily bypassing local user restrictions
    }
  })
}

# 4. Create the Secure IAM Role & Instance Profile for Private Servers
# (This identity token gives private instances capabilities to communicate with the SSM API)
resource "aws_iam_role" "ssm_instance_role" {
  name = "DataCenter-SSM-Managed-Instance-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Attach native Core SSM policies to allow outbound data plane handshakes
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Bind explicit custom write-access permissions to the instance role for logging
resource "aws_iam_role_policy" "instance_logging_privileges" {
  name = "Instance-SSM-Logging-Vault-Access"
  role = aws_iam_role.ssm_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = ["${aws_s3_bucket.session_log_vault.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["${aws_cloudwatch_log_group.ssm_log_group.arn}:*"]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "DataCenter-SSM-Managed-Instance-Profile"
  role = aws_iam_role.ssm_instance_role.name
}
