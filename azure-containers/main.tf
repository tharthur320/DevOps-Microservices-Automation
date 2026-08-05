# =====================================================================
# MULTI-CLOUD PROJECT COMPONENT: ENTERPRISE CONTAINER REGISTRY TIER
# SECURE VAULT FOR MANAGING PRIVATE MICROSERVICE IMAGES ON AZURE
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

# 1. Establish the Logical Resource Group Container
resource "azurerm_resource_group" "container_rg" {
  name     = "Enterprise-Container-RG"
  location = "East US"
}

# 2. Deploy a Secure, Private Azure Container Registry (ACR)
resource "azurerm_container_registry" "private_acr" {
  name                = "elitedevopsregistry2026" # Globally unique alphanumeric name string
  resource_group_name = azurerm_resource_group.container_rg.name
  location            = azurerm_resource_group.container_rg.location
  sku                 = "Basic" # Cost-effective laboratory tier with full enterprise features
  admin_enabled       = true    # Enables secure administrative access keys for Docker authentication

  tags = {
    Component  = "Microservices-Vault"
    SavedAsset = "True"
  }
}
