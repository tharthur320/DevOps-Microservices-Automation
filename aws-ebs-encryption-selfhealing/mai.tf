# =====================================================================
# CERTIFICATION SCENARIO 118: AUTONOMOUS STORAGE COMPLIANCE PIPELINES
# COMPONENT: AWS CONFIG RULES REMEDIATING UNENCRYPTED EBS VOLUMES
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

# 2. Architect the Active EBS Encryption Compliance Auditor Rule
resource "aws_config_config_rule" "ebs_encryption_rule" {
  name        = "ebs-volumes-encrypted-audit"
  description = "Triggers non-compliant status flags if an Amazon EBS block storage volume is spun up unencrypted"

  # Uses a highly optimized AWS Managed Security Rule blueprint checking block storage parameters
  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }

  depends_on = [data.aws_config_configuration_recorder.governance_recorder]
}

# 3. Configure the Autonomous Self-Healing Automation Target
resource "aws_config_remediation_configuration" "storage_self_heal" {
  config_rule_name = aws_config_config_rule.ebs_encryption_rule.name
  target_type      = "SSM_DOCUMENT"
  
  # Target: Native AWS programmatic automation document that purges non-compliant storage elements
  target_id        = "AWS-DeleteEBSVolume" 

  # Automated Parameter Mapping: Injects the non-compliant Volume ID straight into the execution engine
  parameter {
    name         = "VolumeId"
    resource_value = "RESOURCE_ID"
  }

  automatic                  = true # ENFORCES AUTOMATIC REMEDIATION WITHOUT HUMAN INTERVENTION
  maximum_automatic_attempts = 3
  retry_attempt_seconds      = 60
}

# 4. Deploy an EventBridge Message Bus Rule to Stream Compliance Alerts to the SOC
resource "aws_cloudwatch_event_rule" "storage_compliance_alerts" {
  name        = "capture-storage-governance-failures"
  description = "Intercepts dangerous unencrypted block storage modifications across the corporate infrastructure"

  event_pattern = jsonencode({
    "source": ["aws.config"],
    "detail-type": ["Config Rules Compliance Change"],
    "detail": {
      "newEvaluationResult": {
        "complianceType": ["NON_COMPLIANT"]
      },
      "configRuleName": ["ebs-volumes-encrypted-audit"]
    }
  })
}
