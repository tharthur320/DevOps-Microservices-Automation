# =====================================================================
# CERTIFICATION SCENARIO 93: SECURE EXTERNAL SAAS DATA INGESTION
# COMPONENT: AMAZON APPFLOW FLOWS CHANNELING PAYLOADS TO ENCRYPTED S3
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

# 1. Reference Your Central Cross-Region Cryptographic Master KMS Key
data "aws_kms_key" "master_crypto_key" {
  key_id = "alias/enterprise-global-core-key" # Reuses your secure Phase 3 key ciphers
}

# 2. Provision the Isolated S3 Landing Vault Bucket for SaaS Metrics Ingestion
resource "aws_s3_bucket" "saas_landing_vault" {
  bucket        = "enterprise-saas-salesforce-ingest-vault-2026"
  force_destroy = false
}

# 3. Architect the Enterprise AppFlow Automated Data Synchronization Pipeline
resource "aws_appflow_flow" "salesforce_sync" {
  name        = "enterprise-salesforce-to-s3-sync-channel"
  description = "Serverless automated ingestion pipeline copying financial records privately into S3"
  trigger_config {
    trigger_type = "Scheduled" # Run the ingestion pipeline automatically on a scheduled cron cadence
    
    trigger_properties {
      scheduled {
        schedule_expression = "cron(0 22 * * ? *)" # Execute every single night at 10:00 PM UTC
        data_pull_mode     = "Incremental"        # Capture only fresh database mutations to save platform bandwidth
      }
    }
  }

  # SOURCE DIRECTION: Ingest datasets natively from your Salesforce organization objects
  source_flow_config {
    connector_type = "Salesforce"
    source_connector_properties {
      salesforce {
        object = "Account" # Targets the central customer master account ledger rows
      }
    }
  }

  # TARGET DIRECTION: Stream and copy clean data blocks into your encrypted S3 vault
  destination_flow_config {
    connector_type = "S3"
    s3_destination_properties {
      bucket_name = aws_s3_bucket.saas_landing_vault.id
      bucket_prefix = "salesforce-accounts-data/"

      s3_output_format_config {
        file_type = "JSON" # Package the streaming API fields into configuration JSON structures
        aggregation_config {
          aggregation_type = "None"
        }
      }
    }
  }

  # DATA MAPPING SCHEMAS: Translates external SaaS fields into target data store properties
  tasks {
    source_fields = ["Id"]
    task_type     = "Map"
    destination_field = "Customer_ID"
    task_properties = {
      DESTINATION_DATA_TYPE = "string"
    }
  }

  tasks {
    source_fields = ["AnnualRevenue"]
    task_type     = "Map"
    destination_field = "Annual_Revenue"
    task_properties = {
      DESTINATION_DATA_TYPE = "number"
    }
  }

  # KMS KEY POLICY BINDING: Cryptographically locks the data plane transit blocks
  kms_arn = data.aws_kms_key.master_crypto_key.arn

  tags = {
    Layer      = "SaaS-Ingestion-Perimeter"
    SavedAsset = "True"
  }
}
