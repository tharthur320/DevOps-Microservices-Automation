# =====================================================================
# CERTIFICATION SCENARIO 177: AUTONOMOUS DATABASE STORAGE GOVERNANCE
# COMPONENT: AWS CONFIG RULES AUTOMATICALLY ENFORCING RDS AUTO-SCALING
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
  name = "enterprise-storage-compliance-recorder" # References your active infrastructure recorder!
}

# 2. Architect the Active RDS Storage Auto-Scaling Compliance Auditor Rule
resource "aws_config_config_rule" "rds_autoscaling_rule" {
  name        = "rds-storage-autoscaling-enabled-audit"
  description = "Triggers non-compliant status flags if an Amazon RDS database instance has storage auto-scaling disabled"

  # Uses a highly optimized AWS Managed Security Rule blueprint checking database scaling states
  source {
    owner             = "AWS"
    source_identifier = "RDS_STORAGE_AUTOSCALING_ENABLED"
  }

  depends_on = [data.aws_config_configuration_recorder.core_recorder]
}

# 3. Configure the Autonomous Self-Healing Storage Automation Target Broker
resource "aws_config_remediation_configuration" "database_storage_self_heal" {
  config_rule_name = aws_config_config_rule.rds_autoscaling_rule.name
  target_type      = "SSM_DOCUMENT"
  
  # Target: Native AWS programmatic automation document that activates RDS storage auto-scaling
  target_id        = "AWS-ModifyRDSInstanceStorageAutoscaling" 

  # AUTOMATED PARAMETER MAPPING: Injects the bad DB Instance Identifier straight into the remediation runner
  parameter {
    name         = "DBInstanceIdentifier"
    resource_value = "RESOURCE_ID"
  }

  # Hardcodes the strict maximum scalable storage ceiling parameter into the task
  parameter {
    name         = "MaxAllocatedStorage"
    static_value = "1000" # Force a safe dynamic scaling boundary of up to 1000 GB
  }

  automatic                  = true # ENFORCES AUTOMATIC REMEDIATION WITHOUT HUMAN INTERVENTION
  maximum_automatic_attempts = 3
  retry_attempt_seconds      = 60
}

# 4. Deploy an EventBridge Message Bus Rule to Stream Compliance Alerts to the SOC
resource "aws_cloudwatch_event_rule" "database_autoscaling_alerts" {
  name        = "capture-rds-autoscaling-remediations"
  description = "Intercepts automated isolation and database hardening events across the data tier"

  event_pattern = jsonencode({
    "source": ["aws.config"],
    "detail-type": ["Config Rules Compliance Change"],
    "detail": {
      "newEvaluationResult": {
        "complianceType": ["NON_COMPLIANT"]
      },
      "configRuleName": ["rds-storage-autoscaling-enabled-audit"]
    }
  })
}
