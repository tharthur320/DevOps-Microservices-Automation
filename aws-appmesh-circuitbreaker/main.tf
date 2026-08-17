# =====================================================================
# CERTIFICATION SCENARIO 111: HIGH-DENSITY MICROSERVICE SERVICE MESHES
# COMPONENT: AWS APP MESH ENVOY PROXIES AUTOMATING CIRCUIT BREAKERS
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

# 1. Provision the Core Authoritative Global App Mesh Control Plane Boundary
resource "aws_appmesh_mesh" "microservice_mesh" {
  name = "enterprise-core-service-mesh"

  spec {
    egress_filter {
      type = "ALLOW_ALL" # Permitting secure routing outward to public endpoints if whitelisted
    }
  }

  tags = {
    Layer      = "Service-Mesh-Core"
    SavedAsset = "True"
  }
}

# 2. Architect the Hardened Virtual Node Wrapper for the Downstream Target Service
# (This step maps network connection boundaries directly onto your Inventory Sync nodes)
resource "aws_appmesh_virtual_node" "inventory_service_node" {
  name      = "inventory-sync-service-node"
  mesh_name = aws_appmesh_mesh.microservice_mesh.name

  spec {
    aws_cloud_map_instance_attribute_value_register {
        service_name = "inventory-sync.local" # Linked to Scenario 55 Discovery Meshes!
    }

    # AUTONOMOUS CIRCUIT BREAKER ENGINE LAYER
    # Hardcodes structural connection parameters directly into the proxy memory fabric
    backend {
      virtual_service {
        virtual_service_name = "inventory-sync.local"
      }
    }

    # CONNECTION POOL BOUNDARIES: The ironclad traffic gating thresholds
    listener {
      port_mapping {
        port     = 8080
        protocol = "http"
      }

      connection_pool {
        http {
          max_connections     = 100 # Maximum concurrent connections permitted before saturation
          max_pending_requests = 10  # Trip the circuit breaker if more than 10 requests queue up un-processed
        }
      }

      # Active health check probes checking the data plane node integrity locally
      health_check {
        protocol            = "http"
        path                = "/health"
        healthy_threshold   = 2
        unhealthy_threshold = 3
        timeout_millis      = 2000
        interval_millis     = 5000
      }
    }
  }
}
