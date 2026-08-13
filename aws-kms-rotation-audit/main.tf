# =====================================================================
# CERTIFICATION SCENARIO 76: CRYPTOGRAPHIC GOVERNANCE AUTOMATION
# COMPONENT: AWS CONFIG & EVENTBRIDGE CAPTURING INSECURE KMS BLOCKS
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

# 2. Architect the Active KMS Key Rotation Compliance Auditor Rule
resource "aws_config_config_rule" "kms_rotation_rule" {
  name        = "kms-key-rotation-enabled-audit"
  description = "Triggers non-compliant status flags if a customer-managed KMS key disables automatic rotation"

  # Uses a highly optimized AWS Managed Security Rule blueprint checking rotation states
  source {
    owner             = "AWS"
    source_identifier = "KMS_KEY_ROTATION_ENABLED"
  }

  depends_on = [data.aws_config_configuration_recorder.governance_recorder]
}

# 3. Reference Your Secure Phase 4 Active Amazon SNS Notification Alert Topic
data "aws_sns_topic" "security_alerts" {
  name = "enterprise-critical-root-access-alerts" # Routes straight to your P1 incident response channels!
}

# 4. Deploy the EventBridge Rule Filtering for KMS Key Compliance Failures
resource "aws_cloudwatch_event_rule" "kms_audit_filter" {
  name        = "capture-kms-rotation-compliance-failures"
  description = "Intercepts AWS Config state evaluations showing un-rotated or un-protected encryption keys"

  # EVENT PATTERN: Monitors the compliance bus explicitly for this target rule failure
  event_pattern = jsonencode({
    "source": ["aws.config"],
    "detail-type": ["Config Rules Compliance Change"],
    "detail": {
      "newEvaluationResult": {
        "complianceType": ["NON_COMPLIANT"]
      },
      "configRuleName": ["kms-key-rotation-enabled-audit"]
    }
  })
}

# 5. Connect the Event Bus Directly to Stream Breach Alerts straight to SNS
resource "aws_cloudwatch_event_target" "sns_security_target" {
  rule      = aws_cloudwatch_event_rule.kms_audit_filter.name
  target_id = "StreamKMSBreachToSecurityOperations"
  arn       = data.aws_sns_topic.security_alerts.arn
}
