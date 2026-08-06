# =====================================================================
# PROJECT: ENTERPRISE LAYER-7 SECURITY (AZURE APP GATEWAY & WAF)
# OWASP-HARDENED PERIMETER SHIELD BLOCKING LAYER-7 WEB EXPLOITS
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
resource "azurerm_resource_group" "waf_rg" {
  name     = "Enterprise-WAF-RG"
  location = "East US"
}

# 2. Build the Underlying Virtual Network Architecture Foundations
resource "azurerm_virtual_network" "waf_vnet" {
  name                = "WAF-Perimeter-VNet"
  resource_group_name = azurerm_resource_group.waf_rg.name
  location            = azurerm_resource_group.waf_rg.location
  address_space       = ["10.250.0.0/16"]
}

resource "azurerm_subnet" "gateway_subnet" {
  name                 = "AppGateway-Dedicated-Subnet"
  resource_group_name  = azurerm_resource_group.waf_rg.name
  virtual_network_name = azurerm_virtual_network.waf_vnet.name
  address_prefixes     = ["10.250.1.0/24"] # Gateway requires a dedicated, isolated subnet block
}

# 3. Provision a Public Static IP for the Front Edge Ingress
resource "azurerm_public_ip" "gateway_ip" {
  name                = "app-gateway-public-ip"
  resource_group_name = azurerm_resource_group.waf_rg.name
  location            = azurerm_resource_group.waf_rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# 4. Architect the Hardened OWASP Core Web Application Firewall Policy
resource "azurerm_web_application_firewall_policy" "waf_policy" {
  name                = "enterprise-core-waf-policy"
  resource_group_name = azurerm_resource_group.waf_rg.name
  location            = azurerm_resource_group.waf_rg.location

  policy_settings {
    enabled = true
    mode    = "Prevention" # Strict Enforcement Posture: Instantly block malicious requests
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2" # Enforces standard open-source web application protection baselines
    }
  }
}

# 5. Deploy the Enterprise Azure Application Gateway (Layer-7 Load Balancer)
resource "azurerm_application_gateway" "app_gateway" {
  name                = "enterprise-waf-gateway"
  resource_group_name = azurerm_resource_group.waf_rg.name
  location            = azurerm_resource_group.waf_rg.location

  sku {
    name     = "WAF_v2" # Mandates Layer-7 inspection-engine capabilities
    tier     = "WAF_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-config"
    subnet_id = azurerm_subnet.gateway_subnet.id
  }

  frontend_port {
    name = "http_port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "my-frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.gateway_ip.id
  }

  backend_address_pool {
    name = "backend-app-pool"
  }

  backend_http_settings {
    name                  = "http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "my-frontend-ip-config"
    frontend_port_name             = "http_port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "request-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "backend-app-pool"
    backend_http_settings_name = "http-settings"
    priority                   = 10
  }

  firewall_policy_id = azurerm_web_application_firewall_policy.waf_policy.id

  tags = {
    Shield     = "Layer7-WAF-Guard"
    SavedAsset = "True"
  }
}
