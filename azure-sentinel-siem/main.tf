# =====================================================================
# PROJECT: ENTERPRISE CLOUD SIEM DEVELOPMENT (LOG ANALYTICS & SENTINEL)
# SECURE TELEMETRY ENGINE FOR AGGREGATING MULTI-CLOUD SECURITY LOGS
# =====================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# 1. Establish the Core Logical Security Grouping Box
resource "azurerm_resource_group" "siem_rg" {
  name     = "Enterprise-SIEM-Operations-RG"
  location = "East US"
}

# 2. Deploy the Centralized Azure Log Analytics Workspace Core Repository
resource "azurerm_log_analytics_workspace" "security_workspace" {
  name                = "elitedevopssiemlogs2026" # Globally unique alphanumeric naming string
  location            = azurerm_resource_group.siem_rg.location
  resource_group_name = azurerm_resource_group.siem_rg.name
  sku                 = "PerGB2018" # Standard commercial data ingestion metric tier
  retention_in_days   = 90         # Enforces strict 90-day retention baseline for forensics audits

  tags = {
    Layer      = "Telemetry-Ingestion"
    SavedAsset = "True"
  }
}

# 3. Instantiate Microsoft Sentinel (SIEM Solution) Layer over the Workspace
resource "azurerm_log_analytics_solution" "sentinel_siem" {
  solution_name         = "SecurityInsights" # Special Azure internal name string mapping to Microsoft Sentinel
  location              = azurerm_resource_group.siem_rg.location
  resource_group_name   = azurerm_resource_group.siem_rg.name
  workspace_resource_id = azurerm_log_analytics_workspace.security_workspace.id
  workspace_name        = azurerm_log_analytics_workspace.security_workspace.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/SecurityInsights"
  }
}

# 4. Engineer a Customized Interactive Threat Telemetry Workbook (Dashboard)
resource "azurerm_sentinel_workbook" "threat_dashboard" {
  name                = "00000000-0000-0000-0000-000000000001" # Required RFC 4122 compliant unique GUID format
  resource_group_name = azurerm_resource_group.siem_rg.name
  location            = azurerm_resource_group.siem_rg.location
  display_name        = "MultiCloud-Threat-Detection-Workbook"
  workspace_id        = azurerm_log_analytics_workspace.security_workspace.id

  # JSON payload structure configuring specialized visual graphs for cross-cloud anomaly analytics
  content_json = jsonencode({
    "version" = "Notebook/1.0",
    "items" = [
      {
        "type" = 1,
        "name" = "heading_block",
        "markup" = "# Multi-Cloud Security Analytics Dashboard\nTelemetry streams monitoring unauthorized administrative behaviors across AWS IAM logs and Azure Entra ID logs simultaneously."
      },
      {
        "type" = 3,
        "name" = "query_block",
        "query" = "SecurityEvent | where EventID == 4625 | summarize Count=count() by Account", # Ingesting your brute force forensics logs!
        "typeSettings" = {
          "visualization" = "barchart"
        }
      }
    ]
  })

  depends_on = [azurerm_log_analytics_solution.sentinel_siem]
}
