# =====================================================================
# CERTIFICATION SCENARIO 104: SELF-SERVICE COMPLIANCE AUTOMATIONS
# COMPONENT: AWS SERVICE CATALOG MATRICES ENFORCING INFRASTRUCTURE BASELINES
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

# 1. Provision the Central Governance Service Catalog Portfolio (The Corporate Store)
resource "aws_servicecatalog_portfolio" "corporate_factory" {
  name          = "Enterprise-Approved-Core-Infrastructure"
  description   = "Hardened, pre-audited baseline infrastructure assets for development teams"
  provider_name = "Cloud Security Operations Center"

  tags = {
    Layer      = "Self-Service-Governance"
    SavedAsset = "True"
  }
}

# 2. Architect an Approved Secure Infrastructure Product (Hardened EC2 Template)
resource "aws_servicecatalog_product" "secure_compute_product" {
  name  = "Hardened-Linux2023-ApplicationNode"
  owner = "Cloud Security Operations Center"
  type  = "CLOUD_FORMATION_TEMPLATE" # Service Catalog wraps baseline provisioning templates natively

  provisioning_artifact_parameters {
    name         = "v1.0.0-baseline"
    description  = "Initial secure production-ready computing node layout tracking zero-ssh standards"
    template_url = "https://amazonaws.com"
    type         = "CLOUD_FORMATION_TEMPLATE"
  }
}

# 3. Securely Bind the Approved Infrastructure Product to the Corporate Store Portfolio
resource "aws_servicecatalog_product_portfolio_association" "product_binding" {
  portfolio_id = aws_servicecatalog_portfolio.corporate_factory.id
  product_id   = aws_servicecatalog_product.secure_compute_product.id
}

# 4. Associate the Target End-User Access Principal (The Developer Identity Group)
# (Grants your engineering group rights to view and click provision inside the portal)
resource "aws_servicecatalog_principal_portfolio_association" "developer_access" {
  portfolio_id = aws_servicecatalog_portfolio.corporate_factory.id
  principal_arn = "arn:aws:iam::123456789012:role/Enterprise-Cloud-DevOps-Team" # Existing SSO Principal!
  principal_type = "IAM"
}

# 5. HARDENED LAUNCH CONSTRAINT CONFIGURATION: The Least-Privilege Identity Bridge
# This constraint forces the product to build using a specific secure administrative role,
# ensuring the developer calling the action never needs direct write access to your networks.
resource "aws_servicecatalog_constraint" "enforce_launch_role" {
  portfolio_id = aws_servicecatalog_portfolio.corporate_factory.id
  product_id   = aws_servicecatalog_product.secure_compute_product.id
  type         = "LAUNCH"

  parameters = jsonencode({
    RoleArn = "arn:aws:iam::123456789012:role/DataCenter-SSM-Automation-ExecutionRole" # Scenario 74 Execution Role!
  })
}
