# =====================================================================
# CERTIFICATION SCENARIO 74: INFRASTRUCTURE HOUSEKEEPING HARDENING
# COMPONENT: SSM AUTOMATION DOCUMENTS PURGING STALE DATA ASSETS
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

# 1. Architect the Enterprise Automated SSM Housekeeping Automation Runbook
resource "aws_ssm_document" "ami_cleanup_runbook" {
  name            = "Enterprise-Automated-AMICleanup"
  document_type   = "Automation" # Mandates the serverless orchestration workflow engine format
  content_format  = "JSON"

  # AUTOMATION CONTENT: Programs declarative multi-step API remediation actions
  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Serverless execution runbook that safely de-registers stale AMIs and shreds snapshots"
    
    # PARAMETERS MATRIX: Ingests specific resource targets securely from automation triggers
    parameters = {
      TargetImageId = {
        type        = "String"
        description = "The explicit Amazon Machine Image ID string targeted for retirement"
      }
      TargetSnapshotId = {
        type        = "String"
        description = "The trailing EBS block storage snapshot ID bound to the image asset"
      }
      AutomationAssumeRole = {
        type        = "String"
        description = "The secure administrative role execution ARN running the infrastructure actions"
        default     = "arn:aws:iam::123456789012:role/DataCenter-SSM-Automation-ExecutionRole"
      }
    }
    
    mainSteps = [
      {
        # STEP 1: DE-REGISTRATION (Safely un-bind the machine target string from the region registry)
        name   = "DeregisterStaleImage"
        action = "aws:executeAwsApi"
        inputs = {
          Service    = "ec2"
          Api        = "DeregisterImage"
          ImageId    = "{{TargetImageId}}"
        }
        nextStep = "PurgeTrailingSnapshot"
      },
      {
        # STEP 2: STORAGE SHREDDING (Permanently wipe out the raw block data storage footprint)
        name   = "PurgeTrailingSnapshot"
        action = "aws:executeAwsApi"
        inputs = {
          Service    = "ec2"
          Api        = "DeleteSnapshot"
          SnapshotId = "{{TargetSnapshotId}}"
        }
        isEnd = true
      }
    ]
  })

  tags = {
    Layer      = "Automated-Cost-Governance"
    SavedAsset = "True"
  }
}

# 2. Deploy a Scheduled State Manager Association (The Cleanup Cron Trigger)
resource "aws_ssm_association" "scheduled_cleanup_trigger" {
  name             = "AWS-StartAutomationExecution" # Native built-in wrapper executing ssm runbooks
  schedule_expression = "cron(0 0 ? * SAT *)"         # Execute automatically every Saturday night at midnight

  targets {
    key    = "Parameter:TargetImageId"
    values = ["*"] # Linked to tags or lifecycle metadata collectors in multi-account pipelines
  }

  parameters = {
    DocumentName = aws_ssm_document.ami_cleanup_runbook.name
  }
}
