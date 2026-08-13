# =====================================================================
# CERTIFICATION SCENARIO 95: AUTOMATED CLUSTER DATA PLANE LIFECYCLES
# COMPONENT: OPENSEARCH DOMAIN POLICIES DRIVING S3 BACKUP SNAPSHOTS
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

# 1. Reference Your Existing Private OpenSearch Domain (From Scenario 31)
data "aws_opensearch_domain" "analytics_cluster" {
  domain_name = "enterprise-security-analytics"
}

# 2. Deploy an Isolated S3 Storage Vault to Ingest OpenSearch Snapshots
resource "aws_s3_bucket" "opensearch_snapshot_vault" {
  bucket        = "enterprise-opensearch-cluster-snapshots-2026"
  force_destroy = false # Strict safety guardrail: prevents automated code deletion of backups
}

# 3. Create the Secure IAM Role Authorizing OpenSearch to Write to S3
resource "aws_iam_role" "opensearch_snapshot_role" {
  name = "DataCenter-OpenSearch-Snapshot-RegistrationRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege block storage access tokens to the snapshot role
resource "aws_iam_role_policy" "opensearch_s3_snapshot_policy" {
  name = "OpenSearch-S3-Snapshot-Writing-Privileges"
  role = aws_iam_role.opscenter_runner_role.id # Attaches to your existing secure execution role

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.opensearch_snapshot_vault.arn,
          "${aws_s3_bucket.opensearch_snapshot_vault.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "arn:aws:iam::123456789012:role/DataCenter-OpenSearch-Snapshot-RegistrationRole"
      }
    ]
  })
}

# =====================================================================
# SYSTEM EXAM NOTE: OPENSEARCH LIFECYCLE MANAGEMENT (ISM) REGISTRATION
# =====================================================================
# In an actual DOP-C02 exam context, once the repository storage links are active,
# you push the Index State Management (ISM) JSON policy directly into the OpenSearch API.
# Below is the precise JSON definition document managing that automated cycle:

locals {
  opensearch_ism_policy = jsonencode({
    policy = {
      description = "Master corporate OpenSearch index lifecycle policy managing hot-to-cold shifts"
      default_state = "hot"
      states = [
        {
          name = "hot"
          actions = [
            {
              # PARTITION ENGINE: Roll indices into daily segments when they cross size filters
              rollover = {
                min_index_age = "1d"
                min_primary_shard_size = "30gb"
              }
            }
          ]
          transitions = [{ state_name = "cold", conditions = { min_index_age = "7d" } }]
        },
        {
          name = "cold"
          actions = [
            {
              # BACKUP INGESTION: Take an automated snapshot to your secure S3 repository bucket
              snapshot = {
                repository = "enterprise-s3-snapshot-repo"
                snapshot   = "daily-cluster-backup"
              }
            }
          ]
          transitions = [{ state_name = "delete", conditions = { min_index_age = "30d" } }]
        },
        {
          name = "delete"
          actions = [
            {
              # PURGE GATE: Permanently delete the active index segment to save platform costs
              delete = {}
            }
          ]
          transitions = []
        }
      ]
    }
  })
}
