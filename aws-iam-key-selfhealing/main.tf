# =====================================================================
# CERTIFICATION SCENARIO 157: AUTONOMOUS IDENTITY HARDENING
# COMPONENT: AWS CONFIG RULES AUTOMATICALLY DEACTIVATING STALE ACCESS KEYS
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
data "aws_config_configuration_recorder" "identity_recorder" {
  name = "enterprise-storage-compliance-recorder" # References your active infrastructure recorder!
}

# 2. Architect the Active IAM Access Key Rotation Compliance Auditor Rule
resource "aws_config_config_rule" "iam_key_rotation_rule" {
  name        = "iam-access-keys-rotated-audit"
  description = "Triggers non-compliant status flags if an active IAM access key age drifts past 90 days"

  # Uses a highly optimized AWS Managed Security Rule blueprint checking credential ages
  source {
    owner             = "AWS"
    source_identifier = "IAM_ACCESS_KEYS_ROTATED"
  }

  # HARDENED EXAM RULE CUSTOMIZATION: Injects the 90-day absolute operational threshold
  input_parameters = jsonencode({
    maxAccessKeyAge = "90"
  })

  depends_on = [data.aws_config_configuration_recorder.identity_recorder]
}

# 3. Configure the Autonomous Self-Healing Infrastructure Remediator Target Broker
resource "aws_config_remediation_configuration" "identity_self_heal" {
  config_rule_name = aws_config_config_rule.iam_key_rotation_rule.name
  target_type      = "SSM_DOCUMENT"
  
  # Target: Native AWS programmatic automation document that deactivates stale keys
  target_id        = "AWS-DeactivateIAMAccessKey"

  # AUTOMATED PARAMETER MAPPING: Injects the bad User Name and Key ID straight into the remediation runner
  parameter {
    name         = "AccessKeyId"
    resource_value = "RESOURCE_ID"
  }

  parameter {
    name         = "Username"
    # AWS Config rules capture the nested user identifier natively as a secondary parameter string
    resource_value = "RESOURCE_ID" 
  }

  automatic                  = true # ENFORCES AUTOMATIC REMEDIATION WITHOUT HUMAN INTERVENTION
  maximum_automatic_attempts = 3
  retry_attempt_seconds      = 60
}

# 4. Deploy an EventBridge Message Bus Rule to Stream Compliance Alerts to the SOC
resource "aws_cloudwatch_event_rule" "identity_perimeter_alerts" {
  name        = "capture-access-key-deactivations"
  description = "Intercepts automated credential invalidations across the enterprise organization"

  event_pattern = jsonencode({
    "source": ["aws.config"],
    "detail-type": ["Config Rules Compliance Change"],
    "detail": {
      "newEvaluationResult": {
        "complianceType": ["NON_COMPLIANT"]
      },
      "configRuleName": ["iam-access-keys-rotated-audit"]
    }
  })
}
