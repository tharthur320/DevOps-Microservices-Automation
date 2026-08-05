# =====================================================================
# MULTI-CLOUD PROJECT COMPONENT: ENTERPRISE DISASTER RECOVERY NETWORKING
# RESOURCE BLOCKS AND LOGICAL BOUNDARIES FOR MICROSOFT AZURE PLATFORMS
# =====================================================================

# 1. Configure the Azure Resource Manager (AzureRM) Provider Core Engine
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {} # Mandatory block for the Azure provider instantiation sequence
}

# 2. Architect an Enterprise Logical Grouping Boundary (Resource Group)
resource "azurerm_resource_group" "network_rg" {
  name     = "Enterprise-Failover-RG"
  location = "East US" # Establishing our core geographical region mapping
}

# 3. Design the Resilient Core Virtual Network (VNet) Core Foundation
resource "azurerm_virtual_network" "failover_vnet" {
  name                = "Azure-Resilient-VNet"
  resource_group_name = azurerm_resource_group.network_rg.name
  location            = azurerm_resource_group.network_rg.location
  address_space       = ["10.100.0.0/16"] # Segmented classless network allocation block

  tags = {
    Environment = "MultiCloud-DisasterRecovery"
    SavedAsset  = "True"
  }
}

# 4. Create the Edge Security DMZ Subnet Layer
resource "azurerm_subnet" "dmz_subnet" {
  name                 = "Azure-DMZ-Subnet"
  resource_group_name  = azurerm_resource_group.network_rg.name
  virtual_network_name = azurerm_virtual_network.failover_vnet.name
  address_prefixes     = ["10.100.1.0/24"]
}

# 5. Create the Isolated Secure Application Backend Subnet Layer
resource "azurerm_subnet" "app_subnet" {
  name                 = "Azure-Backend-AppSubnet"
  resource_group_name  = azurerm_resource_group.network_rg.name
  virtual_network_name = azurerm_virtual_network.failover_vnet.name
  address_prefixes     = ["10.100.10.0/24"]
}
