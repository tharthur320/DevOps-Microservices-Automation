# =====================================================================
# CERTIFICATION SCENARIO 140: HYBRID RESILIENCE & DATA PLANE RECOVERY
# COMPONENT: SSM RUNBOOKS AUTOMATING GATEWAY STORAGE RECOVERY LOOPS
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

# 1. Reference Your Existing Hybrid Storage Gateway (From Scenario 37)
data "aws_storagegateway_gateway" "hybrid_appliance" {
  gateway_name = "on-premise-datacenter-bridge"
}

# 2. Architect the Centralized Storage Gateway Automation Failover Runbook
resource "aws_ssm_document" "gateway_failover_runbook" {
  name            = "Enterprise-Automated-StorageGatewayFailover"
  document_type   = "Automation" # Mandates the serverless orchestration workflow engine format
  content_format  = "JSON"

  # AUTOMATION CONTENT: Programs declarative multi-step API remediation actions
  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Serverless execution runbook that recovers Storage Gateway snapshots to cloud EBS volumes"
    
    parameters = {
      VolumeArn = {
        type        = "String"
        description = "The explicit Amazon Storage Gateway Volume Amazon Resource Name"
      }
      TargetAvailabilityZone = {
        type        = "String"
        default     = "us-east-1a"
        description = "The target private availability zone rack to deploy the emergency storage asset"
      }
      AutomationAssumeRole = {
        type        = "String"
        default     = "arn:aws:iam::123456789012:role/DataCenter-SSM-Automation-ExecutionRole"
        description = "The administrative execution role running the infrastructure actions"
      }
    }
    
    mainSteps = [
      {
        # STEP 1: FETCH LATEST SNAPSHOT (Pull the newest block image file from the cloud registry)
        name   = "GetLatestVolumeSnapshot"
        action = "aws:executeAwsApi"
        inputs = {
          Service = "storagegateway"
          Api     = "DescribeStorediSCSIVolumes"
          VolumeARN = "{{VolumeArn}}"
        }
        outputs = [
          {
            Name     = "VolumeSnapshotId"
            Selector = "$.StorediSCSIVolumes.VolumeSnapshotId"
          }
        ]
        nextStep = "CreateCloudRecoveryVolume"
      },
      {
        # STEP 2: CLOUD PROVISIONING (Instantly generate a native EBS drive from the pre-warmed snapshot metadata)
        name   = "CreateCloudRecoveryVolume"
        action = "aws:executeAwsApi"
        inputs = {
          Service          = "ec2"
          Api              = "CreateVolume"
          SnapshotId       = "%%GetLatestVolumeSnapshot.VolumeSnapshotId%%"
          AvailabilityZone = "{{TargetAvailabilityZone}}"
          VolumeType       = "gp3"
          Encrypted        = true # Force full cryptographic disk lock protections on recovery
        }
        isEnd = true
      }
    ]
  })

  tags = {
    Layer      = "Automated-Disaster-Recovery"
    SavedAsset = "True"
  }
}

# 3. Create the EventBridge Rule Catching Inbound Storage Gateway Failure Alerts
resource "aws_cloudwatch_event_rule" "gateway_offline_monitor" {
  name        = "capture-storage-gateway-disconnections"
  description = "Intercepts operational state drops on hybrid data storage volumes"

  # Event Pattern: Filters explicitly for Storage Gateway tracking error statuses
  event_pattern = jsonencode({
    "source": ["aws.storagegateway"],
    "detail-type": ["Storage Gateway Volume Operational Status Notification"],
    "detail": {
      "status": ["OFFLINE", "ERROR"]
    }
  })
}

# 4. Bind the Monitoring Gate Directly to Invoke the Failover Runbook Target
resource "aws_cloudwatch_event_target" "bind_failover_target" {
  rule      = aws_cloudwatch_event_rule.gateway_offline_monitor.name
  target_id = "TriggerStorageGatewaySnapshotFailover"
  arn       = "arn:aws:ssm:us-east-1:123456789012:automation-definition/${aws_ssm_document.gateway_failover_runbook.name}"
  role_arn  = "arn:aws:iam::123456789012:role/DataCenter-EventBridge-SSM-Remediation-Role" # Scenario 25 Role

  # Input Transformer: Dynamically parse out the failing Volume ARN parameter string
  input_transformer {
    input_paths = {
      "VolumeArn" = "$.detail.volumeARN"
    }
    input_template = "{\"VolumeArn\": [<VolumeArn>]}"
  }
}
