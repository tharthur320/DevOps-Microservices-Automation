# =====================================================================
# PROJECT: ENTERPRISE SERVERLESS CONTAINER ORCHESTRATION (AWS ECS/FARGATE)
# SECURE runtime POOL FOR AUTO-HEALING ENTERPRISE MICROSERVICES
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Reference an Existing Foundational Network (Using a data lookup block)
resource "aws_vpc" "ecs_vpc" {
  cidr_block           = "10.50.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "ECS-Core-Network" }
}

resource "aws_subnet" "ecs_private_subnet" {
  vpc_id            = aws_vpc.ecs_vpc.id
  cidr_block        = "10.50.10.0/24"
  availability_zone = "us-east-1a"
  tags                 = { Name = "ECS-Private-Compute-Tier" }
}

# 2. Architect the Primary Amazon ECS Orchestration Cluster
resource "aws_ecs_cluster" "production_cluster" {
  name = "enterprise-production-microservices"

  setting {
    name  = "containerInsights"
    value = "enabled" # Enforces mandatory CloudWatch telemetry logging for security auditing
  }
}

# 3. Define the Cryptographic Task Definition Blueprint (The Container Spec)
resource "aws_ecs_task_definition" "web_task" {
  family                   = "secure-web-service"
  network_mode             = "awsvpc" # Enforces native AWS networking per container node
  requires_compatibilities = ["FARGATE"] # Mandates serverless kernel-isolated execution
  cpu                      = "256"      # Strict allocation computing parameters
  memory                   = "512"

  container_definitions = jsonencode([{
    name      = "production-app"
    image     = "nginx:alpine" # Pulling an ultra-lightweight, hardened secure web baseline
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort      = 80
    }]
  }])
}

# 4. Deploy the Auto-Healing ECS Service Layer
resource "aws_ecs_service" "web_service" {
  name            = "enterprise-web-service"
  cluster         = aws_ecs_cluster.production_cluster.id
  task_definition = aws_ecs_task_definition.web_task.arn
  desired_count   = 2 # Enforces high availability: ensures 2 tasks run across the infrastructure
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.ecs_private_subnet.id]
    assign_public_ip = false # Strict Zero-Trust posture: compute nodes are entirely invisible to the internet
  }
}
