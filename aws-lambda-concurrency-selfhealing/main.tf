# =====================================================================
# CERTIFICATION SCENARIO 197: AUTONOMOUS SERVERLESS GOVERNANCE
# COMPONENT: AWS CONFIG RULES AUTOMATICALLY ENFORCING LAMBDA CONCURRENCY
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

# 2. Architect the Active Lambda Concurrency Compliance Auditor Rule
resource "aws_config_config_rule" "lambda_concurrency_rule" {
  name        = "lambda-concurrency-allocated-audit"
  description = "Triggers non-compliant status flags if a production AWS Lambda function operates without reserved concurrency settings"

  # Uses a highly optimized AWS Managed Security Rule blueprint checking serverless limits
  source {
    owner             = "AWS"
    source_identifier = "LAMBDA_CONCURRENCY_CHECK"
  }

  depends_on = [data.aws_config_configuration_recorder.core_recorder]
}

# 3. Configure the Autonomous Self-Healing Compute Automation Target Broker
resource "aws_config_remediation_configuration" "compute_concurrency_self_heal" {
  config_rule_name = aws_config_config_rule.lambda_concurrency_rule.name
  target_type      = "SSM_DOCUMENT"
  
  # Target: Native AWS programmatic automation document that configures Lambda concurrency parameters
  target_id        = "AWS-ConfigureLambdaFunctionConcurrency" 

  # AUTOMATED PARAMETER MAPPING: Injects the non-compliant Function Name straight into the remediation runner
  parameter {
    name         = "FunctionName"
    resource_value = "RESOURCE_ID"
  }

  # Hardcodes a strict, safe reserved concurrency safety allocation floor into the task
  parameter {
    name         = "ReservedConcurrentExecutions"
    static_value = "100" # Force a safe minimum high-availability footprint of 100 execution slots
  }

  automatic                  = true # ENFORCES AUTOMATIC REMEDIATION WITHOUT HUMAN INTERVENTION
  maximum_automatic_attempts = 3
  retry_attempt_seconds      = 60
}

# 4. Deploy an EventBridge Message Bus Rule to Stream Compliance Alerts to the SOC
resource "aws_cloudwatch_event_rule" "compute_capacity_alerts" {
  name        = "capture-lambda-concurrency-remediations"
  description = "Intercepts automated isolation and compute capacity hardening events across the serverless tier"

  event_pattern = jsonencode({
    "source": ["aws.config"],
    "detail-type": ["Config Rules Compliance Change"],
    "detail": {
      "newEvaluationResult": {
        "complianceType": ["NON_COMPLIANT"]
      },
      "configRuleName": ["lambda-concurrency-allocated-audit"]
    }
  })
}
