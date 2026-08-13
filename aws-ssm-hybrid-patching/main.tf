# =====================================================================
# CERTIFICATION SCENARIO 92: MULTI-PLATFORM WORKLOAD GOVERNANCE
# COMPONENT: AWS SSM PATCH MANAGER BALANCING LINUX & WINDOWS CLUSTERS
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

# 1. Architect the Hardened Corporate Linux Patch Baseline
resource "aws_ssm_patch_baseline" "linux_baseline" {
  name             = "enterprise-linux-security-baseline"
  operating_system = "AMAZON_LINUX_2023"

  approval_rule {
    approve_after_days = 3 # Wait 3 stability soaking days before auto-approving patches

    patch_filter {
      key    = "CLASSIFICATION"
      values = ["Security", "Bugfix"]
    }
    patch_filter {
      key    = "SEVERITY"
      values = ["Critical", "Important"]
    }
  }
}

# 2. Architect the Matching Corporate Windows Patch Baseline
resource "aws_ssm_patch_baseline" "windows_baseline" {
  name             = "enterprise-windows-security-baseline"
  operating_system = "WINDOWS"

  approval_rule {
    approve_after_days = 3

    patch_filter {
      key    = "CLASSIFICATION"
      values = ["CriticalUpdates", "SecurityUpdates"]
    }
    patch_filter {
      key    = "MSRC_SEVERITY" # Microsoft Security Response Center severity mapping tracking
      values = ["Critical", "Important"]
    }
  }
}

# 3. Connect Both Baselines Securely to a Unified Hybrid Patch Group
resource "aws_ssm_patch_group" "linux_group_binding" {
  baseline_id = aws_ssm_patch_baseline.linux_baseline.id
  patch_group = "hybrid-production-application-cluster"
}

resource "aws_ssm_patch_group" "windows_group_binding" {
  baseline_id = aws_ssm_patch_baseline.windows_baseline.id
  patch_group = "hybrid-production-application-cluster"
}

# 4. Deploy the Unified Maintenance Window (The Operational Safety Window)
resource "aws_ssm_maintenance_window" "hybrid_window" {
  name                        = "hybrid-cluster-weekend-patch-window"
  schedule                    = "cron(0 3 ? * SUN *)" # Trigger automatically every Sunday at 3:00 AM UTC
  duration                    = 4                    # Open the window for exactly 4 hours max
  cutoff                      = 1                    # Stop launching new patching tasks 1 hour before window close
  allow_unassociated_targets = false
}

# 5. Register the Target Hybrid Group Servers into the Maintenance Window
resource "aws_ssm_maintenance_window_target" "hybrid_targets" {
  window_id     = aws_ssm_maintenance_window.hybrid_window.id
  name          = "target-hybrid-cluster-nodes"
  resource_type = "INSTANCE"

  targets {
    key    = "tag:PatchGroup"
    values = ["hybrid-production-application-cluster"] # Targets servers across both OS architectures!
  }
}

# 6. Bind the Automated Run Command Patch Task to the Scheduled Window
resource "aws_ssm_maintenance_window_task" "hybrid_patch_task" {
  max_concurrency = "10%" # Scale parameter: patch up to 10% of the fleet concurrently to protect availability
  max_errors      = "1"   # Fail-Safe Circuit Breaker: Abort operation if even 1 task fails completely
  priority        = 1
  task_arn        = "AWS-RunPatchBaseline" # Native built-in AWS SSM automated orchestration script
  task_type       = "RUN_COMMAND"
  window_id       = aws_ssm_maintenance_window.hybrid_window.id

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.hybrid_targets.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      parameter {
        name   = "Operation"
        values = ["Install"] # Instruction: execute full software update installation commands
      }
    }
  }
}
