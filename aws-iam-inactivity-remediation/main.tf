# =====================================================================
# CERTIFICATION SCENARIO 69: STALE IDENTITY LIFECYCLE MANAGEMENT
# COMPONENT: AWS CONFIG RULES REMEDIATING UNUSED IAM USER CREDENTIALS
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

# 1. Reference Your Central AWS Config Governance Recording Configuration
data "aws_config_configuration_recorder" "core_recorder" {
  name = "enterprise-storage-compliance-recorder" # References your existing Scenario 22 recorder!
}

# 2. Architect the Active IAM Inactivity Compliance Auditor Rule
resource "aws_config_config_rule" "iam_inactivity_rule" {
  name        = "iam-user-unused-credentials-audit"
  description = "Triggers non-compliant status flags if an IAM user sits completely inactive for over 90 days"

  # Uses a highly optimized AWS Managed Security Rule blueprint
  source {
    owner             = "AWS"
    source_identifier = "IAM_USER_UNUSED_CREDENTIALS_CHECK"
  }

  # PARAMETERS CONFIGURATION: Sets the precise threshold parameters for lifecycle rules
  input_parameters = jsonencode({
    maxCredentialUsageAge = "90" # Enforce strict 90-day isolation constraint fence boundaries
  })
}

# 3. Configure the Self-Healing Automation Target (SSM Remediation Configuration)
resource "aws_config_remediation_configuration" "identity_self_heal" {
  config_rule_name = aws_config_config_rule.iam_inactivity_rule.name
  target_type      = "SSM_DOCUMENT"
  
  # Target: Native AWS programmatic remediation document that deactivates access keys
  target_id        = "AWS-RevokeUnusedIAMUserCredentials" 

  # Automated Parameter Mapping: Injects the bad User Name straight into the remediation runner
  parameter {
    name         = "IAMUserId"
    resource_value = "RESOURCE_ID"
  }

  automatic                  = true # ENFORCES AUTOMATIC REMEDIATION WITHOUT HUMAN INTERVENTION
  maximum_automatic_attempts = 3
  retry_attempt_seconds      = 60
}

# 4. Deploy an EventBridge Message Bus Rule to Stream Compliance Alerts to the SOC
resource "aws_cloudwatch_event_rule" "identity_compliance_alerts" {
  name        = "capture-identity-governance-failures"
  description = "Intercepts stale credential compliance failures across the corporate infrastructure"

  event_pattern = jsonencode({
    "source": ["aws.config"],
    "detail-type": ["Config Rules Compliance Change"],
    "detail": {
      "newEvaluationResult": {
        "complianceType": ["NON_COMPLIANT"]
      },
      "configRuleName": ["iam-user-unused-credentials-audit"]
    }
  })
}
