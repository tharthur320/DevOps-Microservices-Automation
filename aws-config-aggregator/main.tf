# =====================================================================
# CERTIFICATION SCENARIO 21: CENTRALIZED CROSS-ACCOUNT COMPLIANCE POOL
# COMPONENT: AWS CONFIG AGGREGATOR SECURING GLOBAL VISIBILITY BOUNDARIES
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Architect the Centralized Multi-Account Multi-Region Configuration Aggregator
# (This resource is deployed directly inside your Central Security Core Account)
resource "aws_config_configuration_aggregator" "central_compliance_hub" {
  name = "enterprise-global-compliance-aggregator"

  # ACCOUNT SOURCE GENERATION: Whitelist and aggregate data from child accounts
  account_aggregation_source {
    account_ids = [
      "111111111111", # Production Hosting Account ID
      "222222222222"  # DevOps Tooling Account ID
    ]
    
    # GLOBAL REGION SCOPE: Command the engine to pull data from all global locations
    all_regions = true 
  }

  tags = {
    Layer      = "Global-Compliance-Hub"
    SavedAsset = "True"
  }
}

# 2. CHILD ACCOUNT BLUEPRINT: Cross-Account Ingestion Authorization Token
# (This explicit resource block is what you deploy inside EACH child account
# to authorize the central security account to pull its compliance records)
resource "aws_config_aggregate_authorization" "authorize_security_hub" {
  # Injected Parameter: The explicit account number of your Central Security Hub
  authorized_account_id = "888888888888" 
  authorized_region     = "us-east-1"

  tags = {
    Boundary = "Compliance-Auth-Token"
  }
}
