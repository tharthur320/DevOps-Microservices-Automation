# =====================================================================
# CERTIFICATION SCENARIO 121: AUTONOMOUS SERVICE DISCOVERY ARCHITECTURES
# COMPONENT: AWS CLOUD MAP SECURING SERVERS-TO-SERVICE CONTAINER LOOKUPS
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

# 1. Reference Your Foundational Infrastructure VPC (Phase 1 Core Network)
data "aws_vpc" "datacenter_vpc" {
  id = "vpc-00000000000000000"
}

# 2. Architect the Authoritative Private Service Discovery DNS Namespace
resource "aws_service_discovery_private_dns_namespace" "internal_mesh" {
  name        = "microservices.local"
  description = "Isolated corporate data plane directory managing serverless microservice lookups"
  vpc         = data.aws_vpc.datacenter_vpc.id
}

# 3. Create the Service Discovery Directory Mapping Register
resource "aws_service_discovery_service" "api_directory" {
  name = "backend-api"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal_mesh.id

    dns_records {
      ttl  = 10 # Low TTL window ensures scaling servers register their fresh IPs instantly
      type = "A"
    }

    routing_policy = "MULTIVALUE" # Returns multiple healthy IP addresses to distribute client load
  }

  health_check_custom_config {
    failure_threshold = 1 # Drops unhealthy task entries instantly if containers fail their check
  }
}

# 4. Reference Your Pre-Staged Multi-Region Container Task (From Scenario 49)
data "aws_ecs_cluster" "production_cluster" {
  cluster_name = "enterprise-production-compute-fleet"
}

data "aws_ecs_task_definition" "core_app" {
  task_definition = "enterprise-core-app-task"
}

# 5. Deploy the Hardened Self-Registering Serverless ECS Fargate Service
resource "aws_ecs_service" "self_registering_service" {
  name            = "enterprise-core-backend-api"
  cluster         = data.aws_ecs_cluster.production_cluster.id
  task_definition = data.aws_ecs_task_definition.core_app.arn
  desired_count   = 4
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = ["subnet-11111111", "subnet-22222222"] # Secure private subnet hallways
    security_group_ids = ["sg-00000000000000000"]
    assign_public_ip = false # Enforces absolute network isolation
  }

  # HARDENED CLOUD MAP AUTONOMIC BINDING
  service_registries {
    registry_arn = aws_service_discovery_service.api_directory.arn
  }
}
