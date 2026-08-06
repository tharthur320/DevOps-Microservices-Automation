# =====================================================================
# PROJECT: ENTERPRISE STORAGE HARDENING (AZURE STORAGE ACCOUNT FIREWALL)
# NETWORK-ISOLATED CLOUD VAULT ACCESSIBLE ONLY VIA PRIVATE NETWORKS
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

# 1. Establish the Core Logical Grouping Box
resource "azurerm_resource_group" "storage_rg" {
  name     = "Enterprise-StorageSecurity-RG"
  location = "East US"
}

# 2. Reference Your Reusable Virtual Network Baseline for Subnet Mapping
resource "azurerm_virtual_network" "secure_vnet" {
  name                = "Storage-Protection-VNet"
  resource_group_name = azurerm_resource_group.storage_rg.name
  location            = azurerm_resource_group.storage_rg.location
  address_space       = ["10.200.0.0/16"]
}

resource "azurerm_subnet" "trusted_app_subnet" {
  name                 = "Trusted-Application-Subnet"
  resource_group_name  = azurerm_resource_group.storage_rg.name
  virtual_network_name = azurerm_virtual_network.secure_vnet.name
  address_prefixes     = ["10.200.1.0/24"]
  
  # Mandatory Configuration: Enable private service link metrics inside this subnet
  service_endpoints    = ["Microsoft.Storage"]
}

# 3. Deploy the Hardened Azure Storage Account Container
resource "azurerm_storage_account" "secure_storage" {
  name                     = "elitedevopsdatastorage26" # Globally unique alphanumeric name
  resource_group_name      = azurerm_resource_group.storage_rg.name
  location                 = azurerm_resource_group.storage_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    DataClassification = "Highly-Confidential"
    SavedAsset         = "True"
  }
}

# 4. Enforce the Layer-3 Storage Account Network Firewall Rules
resource "azurerm_storage_account_network_rules" "storage_firewall" {
  storage_account_id = azurerm_storage_account.secure_storage.id

  # Zero-Trust Default Posture: Block ALL traffic coming from the public internet lines
  default_action             = "Deny"
  
  # Explicit Bypass: Whitelist ONLY traffic originating inside our trusted subnet corridor
  virtual_network_subnet_ids = [azurerm_subnet.trusted_app_subnet.id]
  
  # Administrative Exception: Whitelist secure corporate office IP space if needed
  ip_rules                   = ["203.0.113.50"] 
}
