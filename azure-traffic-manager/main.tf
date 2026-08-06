# =====================================================================
# PROJECT: ENTERPRISE GLOBAL TRAFFIC ROUTING (AZURE TRAFFIC MANAGER)
# GLOBAL DNS MATRIX FOR HIGHLY AVAILABLE MULTI-REGION APP ROUTING
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

# 1. Map Out the Logical Corporate Grouping Box
resource "azurerm_resource_group" "traffic_rg" {
  name     = "Enterprise-GlobalRouting-RG"
  location = "East US"
}

# 2. Architect the Global Traffic Manager Routing Control Profile
resource "azurerm_traffic_manager_profile" "global_routing" {
  name                   = "elitedevops-global-ingress"
  resource_group_name    = azurerm_resource_group.traffic_rg.name
  traffic_routing_method = "Performance" # Routes users to the fastest datacenter based on network latency

  dns_config {
    relative_name = "elitedevopsworldwide" # Creates the unique global sub-domain address string
    ttl           = 30                     # Fast 30-second TTL forces rapid DNS caching updates during disasters
  }

  # Active Health Probes: Automatically ping edge points every 30 seconds to track network health
  monitor_config {
    protocol                     = "HTTP"
    port                         = 80
    path                         = "/"
    interval_in_seconds          = 30
    timeout_in_seconds           = 5
    tolerated_number_of_failures = 3
  }

  tags = {
    Topology   = "Global-DNS-Switchboard"
    SavedAsset = "True"
  }
}

# 3. Define the Primary Cloud Data Center Egress Endpoint Link
resource "azurerm_traffic_manager_azure_endpoint" "primary_endpoint" {
  name               = "primary-datacenter-eastus"
  profile_id         = azurerm_traffic_manager_profile.global_routing.id
  target_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/Mock-RG/providers/Microsoft.Network/publicIPAddresses/mock-ip" # Replaced with live resource IDs
  weight             = 100
}
