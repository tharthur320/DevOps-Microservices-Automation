# =====================================================================
# CERTIFICATION SCENARIO 41: HYBRID MULTI-AZ SHARED STORAGE RESILIENCE
# COMPONENT: AWS EFS REPLICATION RULES & INFREQUENT ACCESS LIFECYCLES
# =====================================================================

# Primary Region Provider block (Virginia Hub)
provider "aws" {
  region = "us-east-1"
}

# Secondary Region Provider block (Oregon Disaster Recovery Hub)
provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

# 1. Deploy the Primary Encrypted Shared EFS File System (Virginia)
resource "aws_efs_file_system" "primary_efs" {
  creation_token   = "enterprise-production-shared-storage"
  encrypted        = true # Mandates full-disk hardware block encryption
  performance_mode = "generalPurpose"
  throughput_mode  = "elastic" # Automatically scales throughput based on application demand

  # COST GOVERNANCE LIFECYCLE: Automatically move cold files to cheaper storage tiers
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS" # Slashes costs by moving un-accessed data to IA
  }

  tags = {
    Layer      = "Global-Shared-Storage"
    SavedAsset = "True"
  }
}

# 2. Architect the Centralized Cross-Region Storage Replication Engine
# (This control plane rule is deployed inside your primary region mapping)
resource "aws_efs_replication_configuration" "cross_region_sync" {
  source_file_system_id = aws_efs_file_system.primary_efs.id

  # DESTINATION ROUTING MAPPING: Automatically duplicate storage frames to Oregon
  destination {
    region = "us-west-2" # Directs the cloud fabric to provision the twin EFS array in the West
  }
}

# =====================================================================
# BACKEND DESTINATION LOOKUP (Executed in Oregon to track the replicated asset)
# =====================================================================
# The underlying AWS engine automatically generates the destination EFS volume in us-west-2.
# We map a data block or reference its state to configure local private mount targets.

# 3. Create the Private Firewall Securing the Network File System (NFS) Port
resource "aws_security_group" "efs_network_fw" {
  name        = "datacenter-efs-internal-firewall"
  description = "Accept inbound shared storage traffic strictly on NFS Port 2049"
  vpc_id      = "vpc-00000000000000000" # References your existing Phase 1 Core VPC ID

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Limits network plane hits strictly to internal data center ranges
  }
}
