# =====================================================================
# CERTIFICATION SCENARIO 53: SECURE INFRASTRUCTURE ACCESS CORRIDORS
# COMPONENT: APPSTREAM 2.0 FLEETS ENFORCING DATA EXFILTRATION CONTROLS
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

# 1. Reference Your Existing Private Network Subnet Infrastructure Core
# (Pins the desktop computing instances deep inside the private hallways)
data "aws_subnet" "private_compute" {
  id = "subnet-11111111" # References your existing secure private subnets
}

data "aws_security_group" "internal_fw" {
  id = "sg-00000000000000000"
}

# 2. Deploy the AppStream 2.0 Core User Access Stack Container
resource "aws_appstream_stack" "admin_stack" {
  name         = "enterprise-admin-desktop-stack"
  description  = "Secure user access stack streaming administrative tools to remote contractors"
  display_name = "Enterprise-Admin-SecureConsole"

  # DATA EXFILTRATION FENCES: Disable local copy/paste and file downloading hooks
  user_settings {
    action     = "CLIPBOARD_COPY_FROM_LOCAL_DEVICE"
    permission = "DISABLED"
  }
  user_settings {
    action     = "CLIPBOARD_COPY_TO_LOCAL_DEVICE"
    permission = "DISABLED"
  }
  user_settings {
    action     = "FILE_DOWNLOAD"
    permission = "DISABLED"
  }
  user_settings {
    action     = "FILE_UPLOAD"
    permission = "DISABLED"
  }

  application_settings {
    enabled        = true
    settings_group = "AdminConsoleSettings"
  }
}

# 3. Architect the Isolated AppStream 2.0 Streaming Compute Fleet
resource "aws_appstream_fleet" "compute_fleet" {
  name          = "enterprise-admin-streaming-fleet"
  display_name  = "Admin-Secure-Compute-Fleet"
  instance_type = "stream.standard.small" # Balanced compute profile optimal for administrative apps
  fleet_type    = "ON_DEMAND"             # Scales computing costs down automatically when idle
  
  # Image: Targets a pre-installed baseline image containing your secure database tools
  image_name    = "Base-Win-Server-2022-Standard" 

  # NETWORK CONTAINMENT LAYER: Restricts the execution hosts to private subnets
  vpc_config {
    subnet_ids         = [data_aws_subnet.private_compute.id]
    security_group_ids = [data_aws_security_group.internal_fw.id]
  }

  compute_capacity {
    desired_instances = 2 # Enforces basic operational high-availability targets
  }

  tags = {
    Layer      = "Hardened-Access-Corridor"
    SavedAsset = "True"
  }
}

# 4. Associate the Compute Fleet Directly to the User Access Stack Boundary
resource "aws_appstream_stack_fleet_association" "fleet_binding" {
  fleet_name = aws_appstream_fleet.compute_fleet.name
  stack_name = aws_appstream_stack.admin_stack.name
}
