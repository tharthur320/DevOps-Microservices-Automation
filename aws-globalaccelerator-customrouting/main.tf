# =====================================================================
# CERTIFICATION SCENARIO 188: GLOBAL INGRESS ACCELERATION & RESILIENCE
# COMPONENT: CUSTOM ROUTING ACCELERATORS FOR DETERMINISTIC CONTAINER ISOLATION
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

# 1. Reference Your Foundational Private Subnet Infrastructure (From Phase 1 Network)
data "aws_subnet" "private_compute_subnet_a" {
  id = "subnet-11111111" # Target private application tier subnet hallway
}

# 2. Provision the Master AWS Global Accelerator Custom Routing Engine
resource "aws_globalaccelerator_custom_routing_accelerator" "deterministic_router" {
  name            = "enterprise-global-custom-routing-accelerator"
  ip_address_type = "IPV4"
  enabled         = true

  tags = {
    Layer      = "Global-Network-CustomRouting"
    SavedAsset = "True"
  }
}

# 3. Deploy the Custom Routing Listener Binding Specific Edge Port Ranges
resource "aws_globalaccelerator_custom_routing_listener" "custom_tcp_listener" {
  accelerator_arn = aws_globalaccelerator_custom_routing_accelerator.deterministic_router.id

  port_range {
    from_port = 8080
    to_port   = 8180 # Defines the deterministic edge port mapping matrix range
  }
}

# 4. Architect the Hardened Custom Routing Endpoint Group Layer
resource "aws_globalaccelerator_custom_routing_endpoint_group" "isolated_endpoint_group" {
  listener_arn          = aws_globalaccelerator_custom_routing_listener.custom_tcp_listener.id
  endpoint_group_region = "us-east-1"

  # DETERNISTIC DESTINATION MATRIX: Maps the network routing plane straight onto private subnet halls
  endpoint_configuration {
    endpoint_id = data.aws_subnet.private_compute_subnet_a.id
  }

  destination_configuration {
    from_port = 80
    to_port   = 80
    protocols = ["TCP"]
  }
}

# 5. Output the Fixed Accelerator ARN to easily connect your Security Invalidation Lambda
output "custom_accelerator_arn" {
  value       = aws_globalaccelerator_custom_routing_accelerator.deterministic_router.id
  description = "The custom routing accelerator handle used by automated circuit-breaking runbooks"
}
