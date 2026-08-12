# =====================================================================
# CERTIFICATION SCENARIO 72: MULTI-ACCOUNT CRYPTOGRAPHIC DELEGATION
# COMPONENT: AWS KMS GRANTS DELEGATING CROSS-ACCOUNT COMPUTE ACCESS
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
  region = "us-east-1" # Deployed inside your Central DevOps Tooling Account
}

# 1. Reference Your Existing Phase 3 Customer-Managed Master KMS Key
data "aws_kms_key" "master_ami_key" {
  key_id = "alias/enterprise-global-core-key"
}

# 2. Architect the Scope-Restricted Programmatic KMS Grant Link
# (Delegates secure crypto rights straight to the Production ASG service)
resource "aws_kms_grant" "asg_cross_account_grant" {
  name              = "production-asg-ami-decryption-grant"
  key_id            = data.aws_kms_key.master_ami_key.arn
  
  # GRANTEE IDENTITY MAPPING: Targets the native ASG service role inside the Production Account
  grantee_principal = "arn:aws:iam::888888888888:role/aws-service-role/://amazonaws.com"

  # OPERATIONS WHITELIST: Restrict the grant to the bare minimum actions needed to boot servers
  operations = [
    "Encrypt",
    "Decrypt",
    "GenerateDataKey",
    "GenerateDataKeyWithoutPlaintext",
    "ReEncryptFrom",
    "ReEncryptTo"
  ]

  # CRITICAL STRUCTURAL GUARDRAIL: Restricts the cryptographic privilege 
  # strictly to internal system scaling requests, blocking manual abuse vectors
  constraints {
    encryption_context_equals = {
      "aws:autoscaling:groupName" = "enterprise-graceful-autoscaling-fleet" # Existing Scenario 65 ASG!
    }
  }

  retiring_principal = "arn:aws:iam::888888888888:root" # Allows the production account to retire the grant when done
}
