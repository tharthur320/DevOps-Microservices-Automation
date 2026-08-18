# =====================================================================
# CERTIFICATION SCENARIO 180: GLOBAL CONFIGURATION GOVERNANCE
# COMPONENT: SSM RESOURCE DATA SYNC EXPORTING MULTI-ACCOUNT ASSET CORRIDORS
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
  region = "us-east-1" # Deployed inside your Central Master Log-Archive Account
}

# 1. Reference Your Centralized Multi-Account Governance S3 Storage Bucket Vault
# (This acts as the master landing pad where cross-account inventory data streams)
data "aws_s3_bucket" "central_inventory_vault" {
  name = "enterprise-multicloud-ssm-inventory-sync-2026" # Reuses your secure Phase 2 vault!
}

# 2. Architect the Global Multi-Account SSM Resource Data Sync Configuration
# This resource forces child compute instances to stream asset catalogs to the hub bucket.
resource "aws_ssm_resource_data_sync" "global_inventory_sync" {
  name = "enterprise-global-organizational-inventory-sync"

  s3_destination {
    bucket_name = data.aws_s3_bucket.central_inventory_vault.id
    region      = "us-east-1"
    prefix      = "ssm-inventory-data"

    # HARDENED AUDITING CORE: Enforces native AWS Organizations multi-account auto-discovery
    sync_source {
      source_type = "Organization"
      
      # Automatically sync tracking metadata from ALL active AWS regions globally
      source_regions = ["ALL_REGIONS"] 
    }
  }
}

# =====================================================================
# FORENSIC QUERY MAPPING REFERENCE: SCENARIO 137 INTEGRATION
# =====================================================================
# Because these inventory configuration files stream cleanly into your 
# central S3 logs bucket, the Amazon Athena big-data query engines we 
# deployed can run SQL operations straight over this aggregated fleet 
# inventory matrix, enabling sub-second tracking of rogue package versions.
