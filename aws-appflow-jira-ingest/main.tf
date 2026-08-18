# =====================================================================
# CERTIFICATION SCENARIO 184: SECURE SAAS GOVERNANCE INGESTION
# COMPONENT: AMAZON APPFLOW CHANNELS JIRA AUDITS TO ENCRYPTED S3
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
  key_id = "alias/enterprise-global-sync-key" # Reuses your secure Phase 3 key ciphers
}

# 2. Provision the Isolated S3 Landing Vault Bucket for SaaS Metrics Ingestion
resource "aws_s3_bucket" "jira_audit_vault" {
  bucket        = "enterprise-saas-jira-compliance-vault-2026"
  force_destroy = false # Safety block: prevents code-driven destruction of compliance logs
}

# 3. Architect the Enterprise AppFlow Automated Data Synchronization Pipeline
resource "aws_appflow_flow" "jira_compliance_sync" {
  name        = "enterprise-jira-to-s3-compliance-channel"
  description = "Serverless automated ingestion pipeline copying incident ticket logs privately into S3"
  
  trigger_config {
    trigger_type = "Scheduled" # Run the ingestion pipeline automatically on a scheduled cron cadence
    
    trigger_properties {
      scheduled {
        schedule_expression = "cron(0 23 * * ? *)" # Execute every single night at 11:00 PM UTC
        data_pull_mode     = "Incremental"        # Capture only fresh data mutations to save platform bandwidth
      }
    }
  }

  # SOURCE DIRECTION: Ingest datasets natively from your Jira organizational objects
  source_flow_config {
    connector_type = "Jira"
    source_connector_properties {
      jira {
        object = "Issue" # Targets core support and incident ticket metrics and metadata
      }
    }
  }

  # TARGET DIRECTION: Stream and copy clean data blocks into your encrypted S3 vault
  destination_flow_config {
    connector_type = "S3"
    s3_destination_properties {
      bucket_name   = aws_s3_bucket.jira_audit_vault.id
      bucket_prefix = "jira-ticket-archives/"

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
    source_fields = ["id"]
    task_type     = "Map"
    destination_field = "Incident_ID"
    task_properties = {
      DESTINATION_DATA_TYPE = "string"
    }
  }

  tasks {
    source_fields = ["fields.status.name"]
    task_type     = "Map"
    destination_field = "Incident_Status"
    task_properties = {
      DESTINATION_DATA_TYPE = "string"
    }
  }

  tasks {
    source_fields = ["fields.updated"]
    task_type     = "Map"
    destination_field = "Last_Updated"
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
