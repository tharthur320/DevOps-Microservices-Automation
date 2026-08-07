# =====================================================================
# CERTIFICATION SCENARIO 22: AUTOMATED STORAGE VOLUME COMPLIANCE DRIFT
# COMPONENT: AWS CONFIG & SSM RUNBOOKS FOR SELF-HEALING ENCRYPTION
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Reference Your Central AWS Config Governance Recording Configuration
resource "aws_config_configuration_recorder" "storage_recorder" {
  name     = "enterprise-storage-compliance-recorder"
  role_arn = "arn:aws:iam::123456789012:role/MockConfigRole"

  recording_group {
    all_supported                = true
    include_global_resource_types = true
  }
}

# 2. Architect an Active Security Governance Auditor Rule (Checks for EBS Encryption)
resource "aws_config_config_rule" "ebs_encryption_rule" {
  name        = "encrypted-volumes-audit"
  description = "Triggers non-compliant status flags if an EBS storage volume is created without encryption"

  # Uses a highly optimized AWS Managed Security Rule blueprint
  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }

  depends_on = [aws_config_configuration_recorder.storage_recorder]
}

# 3. Configure the Self-Healing Automation Target (SSM Remediation Configuration)
resource "aws_config_remediation_configuration" "storage_self_heal" {
  config_rule_name = aws_config_config_rule.ebs_encryption_rule.name
  target_type      = "SSM_DOCUMENT"
  target_id        = "AWS-DeleteVolume" # Official native AWS programmatic remediation document

  # Automated Parameter Mapping: Injects the bad Volume ID straight into the remediation execution engine
  parameter {
    name         = "VolumeId"
    resource_value = "RESOURCE_ID"
  }

  automatic                  = true # ENFORCES AUTOMATIC REMEDIATION WITHOUT HUMAN INTERVENTION
  maximum_automatic_attempts = 3
  retry_attempt_seconds      = 60
}

# 4. Deploy an EventBridge Message Bus Rule to Stream Compliance Alerts to Operations
resource "aws_cloudwatch_event_rule" "storage_compliance_alerts" {
  name        = "capture-storage-compliance-failures"
  description = "Intercepts non-compliant configuration changes across the storage block layers"

  # Event Pattern: Listens explicitly for AWS Config evaluation state changes indicating failures
  event_pattern = jsonencode({
    "source": ["aws.config"],
    "detail-type": ["Config Rules Compliance Change"],
    "detail": {
      "newEvaluationResult": {
        "complianceType": ["NON_COMPLIANT"]
      }
    }
  })
}
