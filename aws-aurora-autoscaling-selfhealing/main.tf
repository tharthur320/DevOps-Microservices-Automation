# =====================================================================
# CERTIFICATION SCENARIO 187: AUTONOMOUS GLOBAL DATA TIER GOVERNANCE
# COMPONENT: AWS CONFIG RULES AUTOMATICALLY ENFORCING AURORA AUTO-SCALING
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

# 2. Architect the Active Aurora Dynamic Scaling Compliance Auditor Rule
resource "aws_config_config_rule" "aurora_autoscaling_rule" {
  name        = "aurora-replica-autoscaling-enabled-audit"
  description = "Triggers non-compliant status flags if an Amazon Aurora database cluster has read-replica auto-scaling disabled"

  # Uses a highly optimized AWS Managed Security Rule blueprint checking database scaling states
  source {
    owner             = "AWS"
    source_identifier = "AURORA_REPLICA_AUTO_SCALING_ENABLED"
  }

  depends_on = [data.aws_config_configuration_recorder.core_recorder]
}

# 3. Configure the Autonomous Self-Healing Storage Automation Target Broker
resource "aws_config_remediation_configuration" "database_capacity_self_heal" {
  config_rule_name = aws_config_config_rule.aurora_autoscaling_rule.name
  target_type      = "SSM_DOCUMENT"
  
  # Target: Native AWS programmatic automation document that activates Aurora replica auto-scaling
  target_id        = "AWS-EnableAuroraReplicaAutoScaling" 

  # AUTOMATED PARAMETER MAPPING: Injects the bad DB Cluster Identifier straight into the remediation runner
  parameter {
    name         = "DBClusterIdentifier"
    resource_value = "RESOURCE_ID"
  }

  # Hardcodes the strict minimum and maximum scalable replica counts into the task
  parameter {
    name         = "MinCapacity"
    static_value = "2" # Force a safe minimum high-availability footprint of 2 instances
  }

  parameter {
    name         = "MaxCapacity"
    static_value = "15" # Force an elastic ceiling capable of handling severe spikes
  }

  automatic                  = true # ENFORCES AUTOMATIC REMEDIATION WITHOUT HUMAN INTERVENTION
  maximum_automatic_attempts = 3
  retry_attempt_seconds      = 60
}

# 4. Deploy an EventBridge Message Bus Rule to Stream Compliance Alerts to the SOC
resource "aws_cloudwatch_event_rule" "database_capacity_alerts" {
  name        = "capture-aurora-autoscaling-remediations"
  description = "Intercepts automated isolation and database capacity hardening events across the data tier"

  event_pattern = jsonencode({
    "source": ["aws.config"],
    "detail-type": ["Config Rules Compliance Change"],
    "detail": {
      "newEvaluationResult": {
        "complianceType": ["NON_COMPLIANT"]
      },
      "configRuleName": ["aurora-replica-autoscaling-enabled-audit"]
    }
  })
}
