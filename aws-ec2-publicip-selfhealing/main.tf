# =====================================================================
# CERTIFICATION SCENARIO 128: AUTONOMOUS NETWORK BOUNDARY PERIMETERS
# COMPONENT: AWS CONFIG RULES AUTOMATICALLY FENCING PUBLIC EC2 NODES
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
resource "aws_security_group" "network_quarantine_sg" {
  name        = "enterprise-network-public-quarantine-fence"
  description = "Strict isolation container cutting off internal and external routing for exposed public nodes"
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

# 3. Architect the Active EC2 Public IP Compliance Auditor Rule
resource "aws_config_config_rule" "ec2_public_ip_rule" {
  name        = "ec2-instance-no-public-ip-audit"
  description = "Triggers non-compliant status flags if an EC2 computing instance associates a public IP footprint"

  # Uses a highly optimized AWS Managed Security Rule blueprint checking network configurations
  source {
    owner             = "AWS"
    source_identifier = "EC2_INSTANCE_NO_PUBLIC_IP"
  }
}

# 4. Configure the Autonomous Self-Healing Infrastructure Remediator Target
resource "aws_config_remediation_configuration" "network_boundary_self_heal" {
  config_rule_name = aws_config_config_rule.ec2_public_ip_rule.name
  target_type      = "SSM_DOCUMENT"
  
  # Target: Native AWS programmatic automation document that alters hardware security groups
  target_id        = "AWS-ModifyEC2InstanceSecurityGroups"

  # PARAMETERS MATRIX: Injects the non-compliant Instance ID and the Quarantine Security Group ID
  parameter {
    name         = "InstanceId"
    resource_value = "RESOURCE_ID"
  }

  parameter {
    name         = "SecurityGroupIds"
    static_value = aws_security_group.network_quarantine_sg.id
  }

  automatic                  = true # ENFORCES AUTOMATIC REMEDIATION WITHOUT HUMAN INTERVENTION
  maximum_automatic_attempts = 3
  retry_attempt_seconds      = 60
}

# 5. Deploy an EventBridge Message Bus Rule to Stream Compliance Alerts to the SOC
resource "aws_cloudwatch_event_rule" "network_perimeter_alerts" {
  name        = "capture-ec2-public-exposure-remediations"
  description = "Intercepts automated isolation and instance hardening events across the compute tier"

  event_pattern = jsonencode({
    "source": ["aws.config"],
    "detail-type": ["Config Rules Compliance Change"],
    "detail": {
      "newEvaluationResult": {
        "complianceType": ["NON_COMPLIANT"]
      },
      "configRuleName": ["ec2-instance-no-public-ip-audit"]
    }
  })
}
