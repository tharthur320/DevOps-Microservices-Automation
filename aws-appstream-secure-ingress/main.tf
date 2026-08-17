# =====================================================================
# CERTIFICATION SCENARIO 160: EPHEMERAL COMPUTE INGRESS CHANNELS
# COMPONENT: AMAZON APPSTREAM 2.0 FLEETS SANDBOXING USER SESSIONS
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

# 1. Reference Your Foundational Infrastructure Network Halls (Phase 1 VPC)
data "aws_vpc" "datacenter_vpc" {
  id = "vpc-00000000000000000"
}

data "aws_subnet" "private_desktop_a" {
  id = "subnet-11111111" # Isolated management subnet AZ-A
}

data "aws_subnet" "private_desktop_b" {
  id = "subnet-22222222" # Isolated management subnet AZ-B
}

# 2. Provision the AppStream 2.0 Stack Container Controlling User Actions
resource "aws_appstream_stack" "secure_ingress_stack" {
  name         = "enterprise-contractor-secure-desktop-stack"
  description  = "Hardened virtual browser streaming workspace for external technical teams"
  display_name = "Enterprise Secure Workspace"

  # IRONCLAD CLIENT EXFILTRATION PREVENTIONS
  # Block data transfers out of the data center to isolate information loops completely
  user_settings {
    action   = "CLIPBOARD_TO_LOCAL_DEVICE"
    permission = "DISABLED"
  }

  user_settings {
    action   = "CLIPBOARD_TO_REMOTE_SESSION"
    permission = "ENABLED" # Permit code copy-pasting INTO the environment for operations tasks
  }

  user_settings {
    action   = "FILE_UPLOAD"
    permission = "ENABLED" # Permit uploading patch configuration artifacts
  }

  user_settings {
    action   = "FILE_DOWNLOAD"
    permission = "DISABLED" # Permanently block downloading database or source configurations
  }

  user_settings {
    action   = "PRINTING_TO_LOCAL_DEVICE"
    permission = "DISABLED"
  }

  tags = {
    Layer      = "User-Ingress-Isolation"
    SavedAsset = "True"
  }
}

# 3. Deploy the Elastic Computing Fleet Executing the Ephemeral Desktops
resource "aws_appstream_fleet" "compute_fleet" {
  name         = "enterprise-hardened-developer-fleet"
  display_name = "Hardened Technical Compute Fleet"
  image_name   = "Amazon-AppStream2-Sample-Image-02-23-2023" # Uses approved secure golden machine images
  instance_type = "stream.standard.medium"
  fleet_type   = "ON_DEMAND" # Automatically scales instances down when users disconnect to optimize budgets

  compute_capacity {
    desired_instances = 2 # Baseline standby instances available for instant logins
  }

  # HARDENED NETWORK ENVELOPE: Mandates placement deep inside isolated private subnet halls
  vpc_config {
    subnet_ids         = [data.aws_subnet.private_desktop_a.id, data.aws_subnet.private_desktop_b.id]
    security_group_ids = ["sg-00000000000000000"] # Controlled security group blocking direct internet routes
  }

  idle_disconnect_timeout_in_seconds = 600 # Auto-evict user sessions after 10 minutes of complete inactivity
}

# 4. Programmatically Associate the Computing Fleet to the Access Stack Container
resource "aws_appstream_fleet_stack_association" "fleet_association" {
  fleet_name = aws_appstream_fleet.compute_fleet.name
  stack_name = aws_appstream_stack.secure_ingress_stack.name
}
