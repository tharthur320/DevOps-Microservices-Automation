# =====================================================================
# CERTIFICATION SCENARIO 198: AUTONOMOUS NETWORKING PLANE PERIMETERS
# COMPONENT: AWS CONFIG RULES AUTOMATICALLY CLOSING STATELESS NACL DOORS
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
data "aws_config_configuration_recorder" "network_recorder" {
  name = "enterprise-storage-compliance-recorder" # References your active infrastructure recorder!
}

# 2. Architect the Active Stateless NACL Security Compliance Auditor Rule
resource "aws_config_config_rule" "nacl_compliance_rule" {
  name        = "vpc-nacl-hardened-rules-audit"
  description = "Triggers non-compliant status flags if a subnet Network Access Control List allows wide-open unapproved ports"

  # Uses a highly optimized AWS Managed Security Rule blueprint checking stateless firewall parameters
  source {
    owner             = "AWS"
    source_identifier = "VPC_NACL_NO_UNRESTRICTED_INBOUND_TO_REMOTE_PORTS"
  }

  depends_on = [data.aws_config_configuration_recorder.network_recorder]
}

# 3. Configure the Autonomous Self-Healing Network Automation Target Broker
resource "aws_config_remediation_configuration" "network_nacl_self_heal" {
  config_rule_name = aws_config_config_rule.nacl_compliance_rule.name
  target_type      = "SSM_DOCUMENT"
  
  # Target: Native AWS programmatic automation document that alters network access control lists
  target_id        = "AWS-ConfigureNetworkAcl" 

  # AUTOMATED PARAMETER MAPPING: Injects the bad NACL ID straight into the remediation runner
  parameter {
    name         = "NetworkAclId"
    resource_value = "RESOURCE_ID"
  }

  # Hardcodes the strict, restrictive lockdown entries straight into the remediation execution task
  parameter {
    name         = "RuleNumber"
    static_value = "100" # Force rule 100 back to its authoritative audited baseline state
  }

  parameter {
    name         = "Protocol"
    static_value = "6" # TCP Protocol identifier
  }

  parameter {
    name         = "RuleAction"
    static_value = "deny" # Force-clamp an explicit stateless block action onto the target
  }

  automatic                  = true # ENFORCES AUTOMATIC REMEDIATION WITHOUT HUMAN INTERVENTION
  maximum_automatic_attempts = 3
  retry_attempt_seconds      = 60
}

# 4. Deploy an EventBridge Message Bus Rule to Stream Compliance Alerts to the SOC
resource "aws_cloudwatch_event_rule" "network_nacl_alerts" {
  name        = "capture-vpc-nacl-remediations"
  description = "Intercepts automated isolation and stateless firewall hardening events across the networking tier"

  event_pattern = jsonencode({
    "source": ["aws.config"],
    "detail-type": ["Config Rules Compliance Change"],
    "detail": {
      "newEvaluationResult": {
        "complianceType": ["NON_COMPLIANT"]
      },
      "configRuleName": ["vpc-nacl-hardened-rules-audit"]
    }
  })
}
