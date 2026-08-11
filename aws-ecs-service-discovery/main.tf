# =====================================================================
# CERTIFICATION SCENARIO 55: DECOUPLED MICROSERVICES MESH ROUTING
# COMPONENT: AWS CLOUD MAP PRIVATE DNS INTEGRATED WITH ECS REPOSITORIES
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

# 1. Reference Your Existing Private Data Center Network Infrastructure Core
data "aws_vpc" "datacenter_vpc" {
  id = "vpc-00000000000000000" # References your existing Phase 1 Core VPC ID
}

# 2. Deploy the Private Cloud Map DNS Namespace (The Internal Registry Directory)
resource "aws_service_discovery_private_dns_namespace" "internal_mesh" {
  name        = "microservices.local"
  description = "Hardened internal corporate service discovery routing domain"
  vpc         = data.aws_vpc.datacenter_vpc.id
}

# 3. Architect the Service Discovery Logical Routing Registry Block
resource "aws_service_discovery_service" "backend_dns_registry" {
  name = "billing" # Establishes the target endpoint sub-domain string

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal_mesh.id

    dns_records {
      ttl  = 10 # Ultra-low 10-second TTL forces rapid internal routing table updates
      type = "A" # Returns the native, private IPv4 address of the target container task
    }

    routing_policy = "MULTIVALUE" # Returns multiple healthy task IPs to enable basic client-side load balancing
  }

  health_check_custom_config {
    failure_threshold = 1 # Mark a container dead instantly if the container cluster flags an execution failure
  }
}

# 4. Integrate the Service Discovery Registry Directly into the ECS Service Block
resource "aws_ecs_service" "backend_service" {
  name            = "enterprise-backend-billing-service"
  cluster         = "enterprise-production-microservices" # Existing Phase 5 ECS Cluster!
  task_definition = "arn:aws:ecs:us-east-1:123456789012:task-definition/secure-web-service"
  desired_count   = 3
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = ["subnet-11111111"]
    assign_public_ip = false # Strict Zero-Trust Posture: Nodes are entirely hidden from the web
    security_groups  = ["sg-00000000000000000"]
  }

  # SERVICE MESH REGISTRATION INTERFACE
  # Automatically registers fresh task container IPs into Cloud Map under billing.microservices.local
  service_registries {
    registry_arn = aws_service_discovery_service.backend_dns_registry.arn
  }
}
