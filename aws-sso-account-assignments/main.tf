# =====================================================================
# CERTIFICATION SCENARIO 85: CENTRALIZED ACCESS & IDENTITY GOVERNANCE
# COMPONENT: IAM IDENTITY CENTER AUTOMATING CROSS-ACCOUNT ACCESS ROLES
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
  region = "us-east-1" # Deployed exclusively inside your AWS Organizations Root/SSO Delegated Admin Account
}

# 1. Fetch Existing Global Identity Center Instance Context Natively
data "aws_ssoadmin_instances" "central_sso" {}

# 2. Reference Your Central Identity Directory User/Group Metadata
# (Pulls the unique tracking ID for the operational engineering team group)
data "aws_identitystore_group" "devops_engineers" {
  identity_store_id = data.aws_ssoadmin_instances.central_sso.identity_store_ids[0]
  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = "Enterprise-Cloud-DevOps-Team"
    }
  }
}

# 3. Architect the Centralized Least-Privilege Permission Set Baseline Profile
resource "aws_ssoadmin_permission_set" "devops_admin_profile" {
  name             = "Enterprise-DevOps-CloudAdmin-Profile"
  description      = "Centralized administrative profile granting least-privilege cloud platform controls"
  instance_arn     = data.aws_ssoadmin_instances.central_sso.arns[0]
  session_duration = "PT4H" # Hardcodes an ironclad 4-hour max token session duration ceiling

  tags = {
    Layer      = "Centralized-Identity-Governance"
    SavedAsset = "True"
  }
}

# 4. Attach an Ironclad Least-Privilege Inline Security Policy to the Profile
resource "aws_ssoadmin_permission_set_inline_policy" "restrictive_privileges" {
  instance_arn       = data.aws_ssoadmin_instances.central_sso.arns[0]
  permission_set_arn = aws_ssoadmin_permission_set.devops_admin_profile.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowOperationalComputeAndStorageActions"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "s3:ListBucket",
          "s3:GetObject"
        ]
        Resource = "*"
      },
      {
        Sid    = "ExplicitDenyDestructiveActions"
        Effect = "Deny"
        Action = [
          "organizations:LeaveOrganization",
          "aws-portal:*",
          "kms:Delete*"
        ]
        Resource = "*"
      }
    ]
  })
}

# 5. Deploy the Automated Cross-Account SSO Account Assignment Bridge
resource "aws_ssoadmin_account_assignment" "devops_production_access" {
  instance_arn       = data.aws_ssoadmin_instances.central_sso.arns[0]
  permission_set_arn = aws_ssoadmin_permission_set.devops_admin_profile.arn

  # TARGET DEPLOYMENT CORRIDOR
  target_id   = "888888888888" # The explicit 12-digit physical AWS Production Hosting Account ID
  target_type = "AWS_ACCOUNT"

  # GRANTEE MAPPING BINDING
  principal_id   = data.aws_identitystore_group.devops_engineers.group_id
  principal_type = "GROUP" # Directs the engine to provision access for the entire DevOps group simultaneously
}
