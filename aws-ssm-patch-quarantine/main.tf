# =====================================================================
# CERTIFICATION SCENARIO 116: AUTOMATED INFRASTRUCTURE SELF-HEALING
# COMPONENT: AWS CONFIG RULES QUARANTINING NON-COMPLIANT COMPUTING NODES
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

# 1. Reference Your Foundational Network Data Core (Phase 1 Core VPC)
data "aws_vpc" "datacenter_vpc" {
  id = "vpc-00000000000000000"
}

# 2. Deploy the Isolated Restrictive Quarantine Security Group Fence
resource "aws_security_group" "host_quarantine_sg" {
  name        = "enterprise-host-quarantine-fence"
  description = "Strict isolation container cutting off internal routing for unpatched nodes"
  vpc_id      = data.aws_vpc.datacenter_vpc.id

  # OUTBOUND RULE ONLY: Allows the SSM Agent to talk out to AWS APIs for remote patching remediation
  egress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "Permit secure HTTPS egress to public AWS Systems Manager endpoints"
  }

  # INBOUND BLOCKS: Zero inbound rules declared, permanently welding all ingress doors shut
}

# 3. Architect the Active SSM Patch Compliance Auditor Rule
resource "aws_config_config_rule" "patch_compliance_rule" {
  name        = "ssm-patch-compliance-audit"
  description = "Triggers non-compliant status flags if a managed host fails its baseline patch parameters"

  # Uses a highly optimized AWS Managed Security Rule blueprint checking system update matrices
  source {
    owner             = "AWS"
    source_identifier = "PATCH_COMPLIANCE_STATUS_CHECK"
  }
}

# 4. Configure the Self-Healing Infrastructure Remediator Target
resource "aws_config_remediation_configuration" "patch_self_heal" {
  config_rule_name = aws_config_config_rule.patch_compliance_rule.name
  target_type      = "SSM_DOCUMENT"
  
  # Target: Native AWS programmatic automation document that alters hardware security groups
  target_id        = "AWS-ModifyEC2InstanceSecurityGroups"

  # PARAMETERS MATRIX: Injects the target Instance ID and the Quarantine Security Group ID
  parameter {
    name         = "InstanceId"
    resource_value = "RESOURCE_ID"
  }

  parameter {
    name         = "SecurityGroupIds"
    static_value = aws_security_group.host_quarantine_sg.id
  }

  automatic                  = true # ENFORCES AUTOMATIC REMEDIATION WITHOUT HUMAN INTERVENTION
  maximum_automatic_attempts = 3
  retry_attempt_seconds      = 60
}

# 5. Deploy an EventBridge Message Bus Rule to Stream Quarantine Alerts to the SOC
resource "aws_cloudwatch_event_rule" "quarantine_compliance_alerts" {
  name        = "capture-host-quarantine-actions"
  description = "Intercepts automated isolation and patching failures across the computing tier"

  event_pattern = jsonencode({
    "source": ["aws.config"],
    "detail-type": ["Config Rules Compliance Change"],
    "detail": {
      "newEvaluationResult": {
        "complianceType": ["NON_COMPLIANT"]
      },
      "configRuleName": ["ssm-patch-compliance-audit"]
    }
  })
}
