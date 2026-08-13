# =====================================================================
# CERTIFICATION SCENARIO 88: SELF-HEALING IDENTITY COMPLIANCE
# COMPONENT: AWS CONFIG RULES DETECTING & STRIPPING ROGUE IAM POLICIES
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
data "aws_config_configuration_recorder" "governance_recorder" {
  name = "enterprise-storage-compliance-recorder" # References your active infrastructure recorder!
}

# 2. Architect the Active IAM Policy Compliance Auditor Rule
resource "aws_config_config_rule" "iam_admin_access_rule" {
  name        = "iam-policy-no-admin-access-audit"
  description = "Triggers non-compliant status flags if an IAM customer-managed policy grants full administrative access"

  # Uses a highly optimized AWS Managed Security Rule blueprint checking policy statements
  source {
    owner             = "AWS"
    source_identifier = "IAM_POLICY_NO_STATEMENTS_WITH_ADMIN_ACCESS"
  }

  depends_on = [data.aws_config_configuration_recorder.governance_recorder]
}

# 3. Configure the Self-Healing Automation Target (SSM Remediation Configuration)
resource "aws_config_remediation_configuration" "iam_policy_self_heal" {
  config_rule_name = aws_config_config_rule.iam_admin_access_rule.name
  target_type      = "SSM_DOCUMENT"
  
  # Target: Native AWS programmatic remediation document that neutralizes open policies
  target_id        = "AWS-RemediateIAMPolicy" 

  # Automated Parameter Mapping: Injects the non-compliant Policy ARN straight into the execution engine
  parameter {
    name         = "PolicyArn"
    resource_value = "RESOURCE_ID"
  }

  automatic                  = true # ENFORCES AUTOMATIC REMEDIATION WITHOUT HUMAN INTERVENTION
  maximum_automatic_attempts = 3
  retry_attempt_seconds      = 60
}

# 4. Deploy an EventBridge Message Bus Rule to Stream Compliance Alerts to the SOC
resource "aws_cloudwatch_event_rule" "iam_compliance_alerts" {
  name        = "capture-iam-policy-governance-failures"
  description = "Intercepts dangerous wildcard identity policy changes across the corporate infrastructure"

  event_pattern = jsonencode({
    "source": ["aws.config"],
    "detail-type": ["Config Rules Compliance Change"],
    "detail": {
      "newEvaluationResult": {
        "complianceType": ["NON_COMPLIANT"]
      },
      "configRuleName": ["iam-policy-no-admin-access-audit"]
    }
  })
}
