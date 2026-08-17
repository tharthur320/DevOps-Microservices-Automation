# =====================================================================
# CERTIFICATION SCENARIO 167: MULTI-ACCOUNT SECURITY GOVERNANCE
# COMPONENT: AWS CONFIG AGGREGATORS POOLING ORGANIZATIONAL COMPLIANCE
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
  region = "us-east-1" # Deployed exclusively inside your Central Master Security Account
}

# 1. Create the Secure IAM Execution Role for the Global Organization Aggregator
resource "aws_iam_role" "config_aggregator_role" {
  name = "DataCenter-Config-OrganizationalAggregator-ExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Attach native AWS managed policy allowing the recorder to poll account lists from the Org API
resource "aws_iam_role_policy_attachment" "config_aggregator_org_policy" {
  role       = aws_iam_role.config_aggregator_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRoleForOrganizations"
}

# 2. Provision the Central Master AWS Config Organization Aggregator Hub
# (This acts as the master multi-account data funnel pooling compliance stats)
resource "aws_config_configuration_aggregator" "organization_aggregator" {
  name = "enterprise-global-organizational-compliance-aggregator"

  organization_aggregation_source {
    all_regions = true # Aggregate tracking data from every active AWS region globally
    role_arn    = aws_iam_role.config_aggregator_role.arn
  }

  tags = {
    Layer      = "Global-Compliance-Aggregation"
    SavedAsset = "True"
  }

  depends_on = [aws_iam_role_policy_attachment.config_aggregator_org_policy]
}

# =====================================================================
# ANALYTICS MAPPING REFERENCE: SCENARIO 137 INTEGRATION
# =====================================================================
# These compliance records stream directly into your central S3 data 
# lakes, enabling the Amazon Athena database schemas we built to run 
# forensic queries against the multi-account aggregation matrix.
