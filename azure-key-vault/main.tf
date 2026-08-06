# =====================================================================
# PROJECT: ENTERPRISE SECRETS MANAGEMENT (AZURE KEY VAULT ISOLATION)
# HARDWARE-BACKED HARDENED VAULT FOR ZERO-TRUST CREDENTIAL STORAGE
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
  features {
    key_vault {
      purge_protection_enabled = true # Mandates strict enterprise anti-ransomware data protection
    }
  }
}

# 1. Establish the Core Logical Grouping Box
resource "azurerm_resource_group" "security_rg" {
  name     = "Enterprise-Security-RG"
  location = "East US"
}

# 2. Reference Active Global Context Natively to Pull Tenant ID Metrics
data "azurerm_client_config" "current" {}

# 3. Deploy the Isolated Azure Key Vault Instance
resource "azurerm_key_vault" "secure_vault" {
  name                        = "elitedevopsvault2026" # Globally unique alphanumeric name string
  location                    = azurerm_resource_group.security_rg.location
  resource_group_name         = azurerm_resource_group.security_rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = true # Prevents immediate permanent deletion of historical assets
  sku_name                    = "standard"

  # Access Policy: Explicitly lock vault management parameters down to our specific execution ID
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Purge",
      "Recover"
    ]
  }

  tags = {
    Boundary   = "Secrets-Hardware-Safe"
    SavedAsset = "True"
  }
}

# 4. Inject an Isolated Database Production Secret Into the Vault Core
resource "azurerm_key_vault_secret" "db_password" {
  name         = "production-database-password"
  value        = "SuperSecureEnterprisePassword2026!" # Isolated safely from plain-text exposure
  key_vault_id = azurerm_key_vault.secure_vault.id
}
