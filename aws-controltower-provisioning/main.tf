# =====================================================================
# CERTIFICATION SCENARIO 51: AUTOMATED MULTI-ACCOUNT ACCOUNT FACTORY
# COMPONENT: CONTROL TOWER PROVISIONING ENFORCING ORGANIZATIONAL BASELINES
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
  region = "us-east-1" # Deployed exclusively inside your AWS Organizations Management Account
}

# 1. Reference Your Central Control Tower Blueprint Core Parameters
# (Pulls the active Control Tower baseline product ID from the AWS Catalog metadata)
data "aws_servicecatalog_launch_paths" "control_tower_path" {
  product_id = "prod-controltoweraccountfactory"
}

# 2. Architect the Automated Account Factory Vending Machine Engine
resource "aws_controltower_account_provisioning" "new_team_account" {
  account_name               = "Enterprise-Staging-AppTier"
  account_email              = "cloud-staging-team@elitedevopsenterprise.com"
  target_organizational_unit = "Core-Staging-OU" # Binds the account to your pre-configured OU path

  # PARAMETRIC ACCOUNT SETUP CONTROL: Passes mandatory metadata to the deployment broker
  parameters {
    key   = "AccountEmail"
    value = "cloud-staging-team@elitedevopsenterprise.com"
  }

  parameters {
    key   = "AccountName"
    value = "Enterprise-Staging-AppTier"
  }

  parameters {
    key   = "SSOUserEmail"
    value = "admin-auditor@elitedevopsenterprise.com" # Central Administrator Single Sign-On Hook
  }

  parameters {
    key   = "SSOUserFirstName"
    value = "Security"
  }

  parameters {
    key   = "SSOUserLastName"
    value = "Auditor"
  }

  parameters {
    key   = "ManagedOrganizationalUnit"
    value = "Core-Staging-OU (ou-1111-22222222)" # Explicit organizational mapping ID string
  }

  tags = {
    Layer      = "Organizational-Account-Factory"
    SavedAsset = "True"
  }
}
