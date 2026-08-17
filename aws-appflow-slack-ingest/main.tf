# =====================================================================
# CERTIFICATION SCENARIO 134: SECURE ChatOps GOVERNANCE INGESTION
# COMPONENT: AMAZON APPFLOW CHANNELS SLACK AUDITS TO ENCRYPTED S3
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
resource "aws_s3_bucket" "slack_audit_vault" {
  bucket        = "enterprise-saas-slack-compliance-vault-2026"
  force_destroy = false # Safety block: prevents code-driven destruction of compliance logs
}

# 3. Architect the Enterprise AppFlow Automated Data Synchronization Pipeline
resource "aws_appflow_flow" "slack_compliance_sync" {
  name        = "enterprise-slack-to-s3-compliance-channel"
  description = "Serverless automated ingestion pipeline copying ChatOps logs privately into S3"
  
  trigger_config {
    trigger_type = "Scheduled" # Run the ingestion pipeline automatically on a scheduled cron cadence
    
    trigger_properties {
      scheduled {
        schedule_expression = "cron(0 23 * * ? *)" # Execute every single night at 11:00 PM UTC
        data_pull_mode     = "Incremental"        # Capture only fresh message mutations to save platform bandwidth
      }
    }
  }

  # SOURCE DIRECTION: Ingest datasets natively from your Slack organizational objects
  source_flow_config {
    connector_type = "Slack"
    source_connector_properties {
      slack {
        object = "Conversations" # Targets internal channel message history matrices
      }
    }
  }

  # TARGET DIRECTION: Stream and copy clean data blocks into your encrypted S3 vault
  destination_flow_config {
    connector_type = "S3"
    s3_destination_properties {
      bucket_name   = aws_s3_bucket.slack_audit_vault.id
      bucket_prefix = "slack-chatops-archives/"

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
    destination_field = "Message_ID"
    task_properties = {
      DESTINATION_DATA_TYPE = "string"
    }
  }

  tasks {
    source_fields = ["text"]
    task_type     = "Map"
    destination_field = "Message_Content"
    task_properties = {
      DESTINATION_DATA_TYPE = "string"
    }
  }

  tasks {
    source_fields = ["ts"]
    task_type     = "Map"
    destination_field = "Timestamp"
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
