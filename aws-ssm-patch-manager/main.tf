# =====================================================================
# CERTIFICATION SCENARIO 15: AUTOMATED OPERATING SYSTEM PATCHING
# COMPONENT: AWS SSM PATCH BASELINE & MAINTENANCE WINDOW COMPLIANCE
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Architect the Hardened Corporate Security Patch Baseline
resource "aws_ssm_patch_baseline" "production_baseline" {
  name             = "enterprise-production-patch-baseline"
  operating_system = "AMAZON_LINUX_2023" # Hardens our specific data center OS flavor

  # SELECTION RULE: Automatically approve high-severity security updates
  approval_rule {
    approve_after_days = 5 # Wait 5 days for stability testing before auto-approving

    patch_filter {
      key    = "CLASSIFICATION"
      values = ["Security", "Bugfix"]
    }

    patch_filter {
      key    = "SEVERITY"
      values = ["Critical", "Important"]
    }
  }

  description = "Mandatory data center baseline securing critical OS dependencies automatically"
}

# 2. Deploy the Maintenance Window (The Operational Safety Window)
resource "aws_ssm_maintenance_window" "patch_window" {
  name        = "production-weekend-patch-window"
  schedule    = "cron(0 2 ? * SUN *)" # Execute every Sunday morning at 2:00 AM UTC
  duration    = 3                    # Open the patch window for exactly 3 hours max
  cutoff      = 1                    # Stop launching new patching tasks 1 hour before window ends
  allow_unassociated_targets = false
}

# 3. Register the Target Production Servers into the Maintenance Window
resource "aws_ssm_maintenance_window_target" "target_servers" {
  window_id     = aws_ssm_maintenance_window.patch_window.id
  name          = "target-production-compute-nodes"
  description   = "Targets servers explicitly bound to the production patch group"
  resource_type = "INSTANCE"

  targets {
    key    = "tag:PatchGroup"
    values = ["production-compute-tier"] # Matches your resource metadata tags!
  }
}

# 4. Bind the Automated Patch Task to the Scheduled Maintenance Window
resource "aws_ssm_maintenance_window_task" "patch_execution_task" {
  max_concurrency = "2"   # Limit: Patch only 2 instances simultaneously to preserve cluster availability
  max_errors      = "1"   # Fail-Safe: Abort the entire operation if even 1 patching task fails
  priority        = 1
  task_arn        = "AWS-RunPatchBaseline" # Native built-in AWS SSM automated patching script
  task_type       = "RUN_COMMAND"
  window_id       = aws_ssm_maintenance_window.patch_window.id

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.target_servers.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      # INSTRUCTION: Tell the SSM engine to execute an active Install action
      parameter {
        name   = "Operation"
        values = ["Install"]
      }
    }
  }
}

# 5. Connect the Baseline to a Secure Patch Group Identifier
resource "aws_ssm_patch_group" "production_patch_group" {
  baseline_id = aws_ssm_patch_baseline.production_baseline.id
  patch_group = "production-compute-tier"
}
