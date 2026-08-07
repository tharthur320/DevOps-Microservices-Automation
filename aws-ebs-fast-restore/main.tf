# =====================================================================
# CERTIFICATION SCENARIO 38: HIGH-SPEED INFRASTRUCTURE DISASTER RECOVERY
# COMPONENT: AWS DLM LIFECYCLE POLICIES WITH INTEGRATED FAST RESTORE (FSR)
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Create a Secure IAM Execution Role for the Data Lifecycle Manager (DLM)
resource "aws_iam_role" "dlm_lifecycle_role" {
  name = "DataCenter-DLM-Storage-Lifecycle-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind standard backup management privileges directly to the DLM execution role
resource "aws_iam_role_policy" "dlm_storage_policy" {
  name = "DLM-Storage-Backup-Privileges"
  role = aws_iam_role.dlm_lifecycle_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:CreateSnapshots",
          "ec2:DeleteSnapshot",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:EnableFastSnapshotRestores",
          "ec2:DisableFastSnapshotRestores",
          "ec2:DescribeFastSnapshotRestores"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole"]
        Resource = "*"
      }
    ]
  })
}

# 2. Architect the Enterprise Automated Data Lifecycle Manager Policy
resource "aws_dlm_lifecycle_policy" "fast_restore_policy" {
  description        = "Enterprise data center backup schedule with integrated fast snapshot restore"
  execution_role_arn = aws_iam_role.dlm_lifecycle_role.arn
  state              = "ENABLED" # Instantly arms the automation engine upon compilation

  policy_details {
    resource_types = ["VOLUME"]

    # TARGET SPECIFICATION: Scans for and targets production storage blocks matching metadata tags
    target_tags = {
      DeploymentTier = "production-database-tier"
    }

    schedule {
      name = "DailyProductionBackups"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["02:00"] # Trigger snapshot automatically at 2:00 AM UTC during quiet hours
      }

      retain_rule {
        count = 7 # Automatically rotate and maintain a rolling window of 7 historical snapshots
      }

      tags_to_add = {
        SnapshotType = "Automated-FSR-Warm"
      }

      copy_tags = true

      # FAST SNAPSHOT RESTORE (FSR) ENFORCEMENT CONFIGURATION LAYER
      # Commands AWS to pre-warm block data, eliminating disk initialization lazy-loading latency
      fast_snapshot_restore {
        count = 1 # Keep the most recent daily snapshot pre-warmed for instant recovery
        availability_zones = [
          "us-east-1a" # Pins the accelerated backup material directly to your primary availability zone
        ]
      }
    }
  }

  tags = {
    Layer      = "Automated-Storage-Resilience"
    SavedAsset = "True"
  }
}
