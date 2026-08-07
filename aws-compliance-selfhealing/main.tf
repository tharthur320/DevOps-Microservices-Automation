# =====================================================================
# CERTIFICATION SCENARIO 6: AUTOMATED INFRASTRUCTURE COMPLIANCE DRIFT
# COMPONENT: AWS CONFIG & SSM RUNBOOKS FOR SELF-HEALING FIREWALL SYSTEMS
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Deploy the Central AWS Config Governance Recording Configuration
resource "aws_config_configuration_recorder" "governance_recorder" {
  name     = "enterprise-data-center-recorder"
  role_arn = "arn:aws:iam::123456789012:role/MockConfigRole"

  recording_group {
    all_supported                = true
    include_global_resource_types = true
  }
}

# 2. Architect an Active Security Governance Auditor Rule (Checks for open SSH ports)
resource "aws_config_config_rule" "ssh_restrictive_rule" {
  name        = "restricted-common-ports-audit"
  description = "Triggers non-compliant status flags if Port 22 (SSH) is opened to public traffic"

  # Uses a highly optimized AWS Managed Security Rule blueprint
  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }

  depends_on = [aws_config_configuration_recorder.governance_recorder]
}

# 3. Configure the Self-Healing Automation Target (SSM Remediation Configuration)
resource "aws_config_remediation_configuration" "firewall_self_heal" {
  config_rule_name = aws_config_config_rule.ssh_restrictive_rule.name
  target_type      = "SSM_DOCUMENT"
  target_id        = "AWS-DisablePublicAccessForSecurityGroup" # Official native AWS programmatic remediation document

  # Automated Parameter Mapping: Injects the bad Security Group ID straight into the remediation execution engine
  parameter {
    name         = "SecurityGroupId"
    resource_value = "RESOURCE_ID"
  }

  automatic                  = true # ENFORCES AUTOMATIC REMEDIATION WITHOUT HUMAN INTERVENTION
  maximum_automatic_attempts = 3
  retry_attempt_seconds      = 60
}

# 4. Deploy an EventBridge Message Bus Rule to Stream Compliance Alerts to Operations
resource "aws_cloudwatch_event_rule" "compliance_alerts" {
  name        = "capture-security-compliance-failures"
  description = "Intercepts non-compliant configuration changes across the database networks"

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
