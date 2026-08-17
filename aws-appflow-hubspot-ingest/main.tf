# =====================================================================
# CERTIFICATION SCENARIO 154: SECURE SAAS GOVERNANCE INGESTION
# COMPONENT: AMAZON APPFLOW CHANNELS HUBSPOT AUDITS TO ENCRYPTED S3
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
resource "aws_s3_bucket" "hubspot_audit_vault" {
  bucket        = "enterprise-saas-hubspot-compliance-vault-2026"
  force_destroy = false # Safety block: prevents code-driven destruction of compliance logs
}

# 3. Architect the Enterprise AppFlow Automated Data Synchronization Pipeline
resource "aws_appflow_flow" "hubspot_compliance_sync" {
  name        = "enterprise-hubspot-to-s3-compliance-channel"
  description = "Serverless automated ingestion pipeline copying CRM records privately into S3"
  
  trigger_config {
    trigger_type = "Scheduled" # Run the ingestion pipeline automatically on a scheduled cron cadence
    
    trigger_properties {
      scheduled {
        schedule_expression = "cron(0 23 * * ? *)" # Execute every single night at 11:00 PM UTC
        data_pull_mode     = "Incremental"        # Capture only fresh data mutations to save platform bandwidth
      }
    }
  }

  # SOURCE DIRECTION: Ingest datasets natively from your HubSpot organizational objects
  source_flow_config {
    connector_type = "Hubspot"
    source_connector_properties {
      hubspot {
        object = "contacts" # Targets customer lead contact histories and interaction data
      }
    }
  }

  # TARGET DIRECTION: Stream and copy clean data blocks into your encrypted S3 vault
  destination_flow_config {
    connector_type = "S3"
    s3_destination_properties {
      bucket_name   = aws_s3_bucket.hubspot_audit_vault.id
      bucket_prefix = "hubspot-crm-archives/"

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
    source_fields = ["vid"]
    task_type     = "Map"
    destination_field = "Contact_ID"
    task_properties = {
      DESTINATION_DATA_TYPE = "string"
    }
  }

  tasks {
    source_fields = ["firstname"]
    task_type     = "Map"
    destination_field = "First_Name"
    task_properties = {
      DESTINATION_DATA_TYPE = "string"
    }
  }

  tasks {
    source_fields = ["lastname"]
    task_type     = "Map"
    destination_field = "Last_Name"
    task_properties = {
      DESTINATION_DATA_TYPE = "string"
    }
  }

  # KMS KEY POLICY BINDING: Cryptographically locks the data plane transit blocks
  kms_arn = data.aws_kms_key.master_crypto_key.arn

  tags = {
    Layer      = "SaaS-Compliance-Perimeter"
    SavedAsset = "True"
  }
}
