# =====================================================================
# CERTIFICATION SCENARIO 57: CLUSTERED SHARED STORAGE ARCHITECTURES
# COMPONENT: HIGH-PERFORMANCE EBS IO2 VOLUMES WITH MULTI-ATTACH ROOTS
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

# 1. Reference Your Existing Clustered EC2 Computing Nodes (Primary and Failover)
# (Multi-Attach mandates that all attached instances sit in the same availability zone)
data "aws_instance" "cluster_node_a" {
  instance_id = "i-11111111111111111"
}

data "aws_instance" "cluster_node_b" {
  instance_id = "i-22222222222222222"
}

# 2. Deploy the High-Performance Provisioned IOPS SSD io2 Multi-Attach Volume
resource "aws_ebs_volume" "shared_cluster_block" {
  availability_zone = "us-east-1a" # Mandated zone alignment matching host hardware
  size              = 100          # Allocated baseline capacity parameters (100 GB)
  type              = "io2"        # Multi-Attach is exclusively supported on provisioned io2/io1 architectures
  iops              = 3000         # Hardcoded provisioned input/output operations per second

  # CRITICAL PROVISIONING POSTURE: Arms concurrent multi-host hardware mapping capabilities
  multi_attach_enabled = true 
  encrypted            = true # Mandates hardware block level encryption via Phase 3 KMS keys

  tags = {
    Layer      = "Clustered-Block-Storage"
    SavedAsset = "True"
  }
}

# 3. Securely Bind the Shared Storage Volume to Computing Node A
resource "aws_volume_attachment" "attach_node_a" {
  device_name = "/dev/sdb"
  volume_id   = aws_ebs_volume.shared_cluster_block.id
  instance_id = data.aws_instance.cluster_node_a.id
}

# 4. Simultaneously Bind the EXACT SAME Storage Volume to Computing Node B
resource "aws_volume_attachment" "attach_node_b" {
  device_name = "/dev/sdb"
  volume_id   = aws_ebs_volume.shared_cluster_block.id
  instance_id = data.aws_instance.cluster_node_b.id
}
