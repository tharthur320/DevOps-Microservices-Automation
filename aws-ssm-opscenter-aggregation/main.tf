# =====================================================================
# CERTIFICATION SCENARIO 97: CENTRALIZED INCIDENT MANAGEMENT CONSOLE
# COMPONENT: SSM RESOURCE DATA SYNC AGGREGATING CROSS-ACCOUNT OPSITEMS
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
  region = "us-east-1" # Deployed inside your Central Master Security Account
}

# 1. Reference Your Centralized Multi-Account Compliance S3 Landing Pad Vault
# (This master bucket collects and indexes cross-account metadata)
data "aws_s3_bucket" "central_compliance_vault" {
  name = "enterprise-multicloud-ssm-inventory-sync-2026" # Reuses your Scenario 43 secure vault!
}

# 2. MASTER CENTRAL ACCOUNT: Deploy the Centralized OpsItem Resource Data Sync Aggregator
# (This switch establishes the master landing collection point for the incident mesh)
resource "aws_ssm_resource_data_sync" "central_opscenter_aggregator" {
  name = "enterprise-central-opscenter-incident-aggregator"

  s3_destination {
    bucket_name = data.aws_s3_bucket.central_compliance_vault.bucket
    region      = "us-east-1"
    sync_format = "JsonSerDe"
    prefix      = "aggregated-opsitems/"
  }
}

# 3. CHILD SPOKE ACCOUNT BLUEPRINT: Cross-Account OpsItem Streaming Source Channel
# (This explicit resource block is what you deploy inside EACH child account
# to authorize and route local OpsCenter incidents straight up to the hub)
resource "aws_ssm_resource_data_sync" "spoke_opsitem_sync_source" {
  name = "enterprise-spoke-to-central-opsitem-stream"

  # SYNC SOURCE SPECIFICATION: Extracted from AWS native Multi-Account organization metadata
  sync_source {
    source_type = "AwsOrganizations"
    aws_organizations_source {
      organization_source_type = "ALL" # Aggregate findings across ALL accounts joined to the org
    }
    
    # GLOBAL GEOGRAPHIC SCOPE: Pull operational incidents from all regions worldwide
    source_regions = [
      "us-east-1",
      "us-west-2"
    ]
    
    include_future_regions = true
  }

  s3_destination {
    bucket_name = "enterprise-multicloud-ssm-inventory-sync-2026"
    region      = "us-east-1"
    sync_format = "JsonSerDe"
    prefix      = "spoke-opsitems-telemetry/"
  }
}
