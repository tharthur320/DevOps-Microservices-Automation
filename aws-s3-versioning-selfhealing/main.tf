# =====================================================================
# CERTIFICATION SCENARIO 147: AUTONOMOUS STORAGE VERSIONING LEVEE
# COMPONENT: AWS CONFIG RULES AUTOMATICALLY PROTECTING S3 VERSIONING
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

# 2. Architect the Active S3 Object Versioning Compliance Auditor Rule
resource "aws_config_config_rule" "s3_versioning_rule" {
  name        = "s3-bucket-versioning-enabled-audit"
  description = "Triggers non-compliant status flags if an Amazon S3 storage bucket has versioning disabled"

  # Uses a highly optimized AWS Managed Security Rule blueprint checking bucket versioning states
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_VERSIONING_ENABLED"
  }

  depends_on = [data.aws_config_configuration_recorder.core_recorder]
}

# 3. Configure the Autonomous Self-Healing Storage Automation Target Broker
resource "aws_config_remediation_configuration" "storage_versioning_self_heal" {
  config_rule_name = aws_config_config_rule.s3_versioning_rule.name
  target_type      = "SSM_DOCUMENT"
  
  # Target: Native AWS programmatic automation document that activates S3 object versioning
  target_id        = "AWS-ConfigureS3BucketVersioning" 

  # AUTOMATED PARAMETER MAPPING: Injects the bad Bucket Name straight into the remediation runner
  parameter {
    name         = "BucketName"
    resource_value = "RESOURCE_ID"
  }

  # Hardcodes the strict boolean versioning state enablement parameter into the task
  parameter {
    name         = "VersioningState"
    static_value = "Enabled"
  }

  automatic                  = true # ENFORCES AUTOMATIC REMEDIATION WITHOUT HUMAN INTERVENTION
  maximum_automatic_attempts = 3
  retry_attempt_seconds      = 60
}

# 4. Deploy an EventBridge Message Bus Rule to Stream Compliance Alerts to the SOC
resource "aws_cloudwatch_event_rule" "storage_versioning_alerts" {
  name        = "capture-s3-versioning-remediations"
  description = "Intercepts automated isolation and bucket hardening events across the data tier"

  event_pattern = jsonencode({
    "source": ["aws.config"],
    "detail-type": ["Config Rules Compliance Change"],
    "detail": {
      "newEvaluationResult": {
        "complianceType": ["NON_COMPLIANT"]
      },
      "configRuleName": ["s3-bucket-versioning-enabled-audit"]
    }
  })
}
