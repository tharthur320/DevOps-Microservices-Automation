# =====================================================================
# CERTIFICATION SCENARIO 125: AUTONOMOUS STORAGE BOUNDARY PERIMETERS
# COMPONENT: AWS CONFIG RULES AUTOMATICALLY CLOSING PUBLIC S3 BUCKETS
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

# 2. Architect the Active S3 Public Access Compliance Auditor Rule
resource "aws_config_config_rule" "s3_public_access_rule" {
  name        = "s3-bucket-public-access-prohibited-audit"
  description = "Triggers non-compliant status flags if an Amazon S3 bucket exposes public access block exceptions"

  # Uses a highly optimized AWS Managed Security Rule blueprint checking bucket permissions
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_LEVEL_PUBLIC_ACCESS_PROHIBITED"
  }

  depends_on = [data.aws_config_configuration_recorder.core_recorder]
}

# 3. Configure the Autonomous Self-Healing Automation Target Broker
resource "aws_config_remediation_configuration" "storage_boundary_self_heal" {
  config_rule_name = aws_config_config_rule.s3_public_access_rule.name
  target_type      = "SSM_DOCUMENT"
  
  # Target: Native AWS programmatic automation document that clamps down S3 public access locks
  target_id        = "AWS-ConfigureS3BucketPublicAccessBlock" 

  # AUTOMATED PARAMETER MAPPING: Injects the bad Bucket Name straight into the remediation runner
  parameter {
    name         = "BucketName"
    resource_value = "RESOURCE_ID"
  }

  # Hardcodes the strict boolean lockdown parameters straight into the remediation execution task
  parameter {
    name         = "BlockPublicAcls"
    static_value = "true"
  }

  parameter {
    name         = "IgnorePublicAcls"
    static_value = "true"
  }

  parameter {
    name         = "BlockPublicPolicy"
    static_value = "true"
  }

  parameter {
    name         = "RestrictPublicBuckets"
    static_value = "true"
  }

  automatic                  = true # ENFORCES AUTOMATIC REMEDIATION WITHOUT HUMAN INTERVENTION
  maximum_automatic_attempts = 3
  retry_attempt_seconds      = 60
}

# 4. Deploy an EventBridge Message Bus Rule to Stream Compliance Alerts to the SOC
resource "aws_cloudwatch_event_rule" "storage_perimeter_alerts" {
  name        = "capture-s3-public-exposure-remediations"
  description = "Intercepts automated isolation and bucket hardening events across the data tier"

  event_pattern = jsonencode({
    "source": ["aws.config"],
    "detail-type": ["Config Rules Compliance Change"],
    "detail": {
      "newEvaluationResult": {
        "complianceType": ["NON_COMPLIANT"]
      },
      "configRuleName": ["s3-bucket-public-access-prohibited-audit"]
    }
  })
}
