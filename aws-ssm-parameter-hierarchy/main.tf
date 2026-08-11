# =====================================================================
# CERTIFICATION SCENARIO 56: CENTRALIZED RUNTIME Posture GOVERNANCE
# COMPONENT: AWS SSM PARAMETER STORE ENFORCING PATH HIERARCHIES
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

# 1. Reference Your Phase 3 Customer-Managed Custom KMS Encryption Key
data "aws_kms_key" "parameter_kms_key" {
  key_id = "alias/enterprise-global-core-key"
}

# 2. Architect an Environment Parameter Hierarchy Path (Standard String Parameter)
resource "aws_ssm_parameter" "db_url" {
  name        = "/enterprise/production/database/url" # Slash-delimited organizational path routing
  type        = "String"
  value       = "postgresql://://elitedevopsenterprise.com"
  description = "Production database backend endpoint address baseline asset"

  tags = {
    Environment = "production"
    SavedAsset  = "True"
  }
}

# 3. Architect a Hardened Secure Parameter Node (SecureString)
resource "aws_ssm_parameter" "api_token" {
  name        = "/enterprise/production/api/token"
  type        = "SecureString" # Forces programmatic data plane encryption at rest
  value       = "CryptographicallySecureTokenString2026!"
  key_id      = data.aws_kms_key.parameter_kms_key.arn
  description = "Hardened application API authorization parameter token string"
}

# 4. EXAM-SPECIFIC DESIGN PATTERN MAPPING: Native Secrets Manager Cross-Reference
# Instead of duplicating database passwords inside the parameter store, 
# we construct a reference mapping parameter that dynamically bridges 
# to your existing Phase 5 active Secrets Manager secret vault.
resource "aws_ssm_parameter" "secrets_manager_pointer" {
  name        = "/enterprise/production/database/password_reference"
  type        = "String"
  value       = "/aws/reference/secretsmanager/production-core-rds-credentials" # Specialized AWS system proxy string
  description = "Dynamic system pointer tunnel pulling live credentials straight from Secrets Manager safely"
}
