# =====================================================================
# CERTIFICATION SCENARIO 46: CONTAINER SCHEDULING & COST OPTIMIZATION
# COMPONENT: ECS ORDERED PLACEMENT STRATEGIES AND ZONE SPREAD FENCES
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Reference Your Existing High-Performance Production ECS Cluster
resource "aws_ecs_cluster" "compute_fleet" {
  name = "enterprise-production-compute-fleet"
}

# 2. Reference Your Reusable Task Definition Core Blueprint
resource "aws_ecs_task_definition" "app_task" {
  family                   = "production-core-api"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"] # Placement strategies apply explicitly to EC2 container hosting fleets
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name      = "core-api-worker"
    image     = "nginx:alpine"
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort      = 0 # Enables dynamic host port mapping for optimal instance packing
    }]
  }])
}

# 3. Architect the Secure, High-Availability Production ECS Service
resource "aws_ecs_service" "production_secure_service" {
  name            = "production-secure-web-service"
  cluster         = aws_ecs_cluster.compute_fleet.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 4

  # STRATEGY PHASE 1: Spread containers evenly across physically separate Availability Zones
  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  # STRATEGY PHASE 2: Spread containers evenly across individual EC2 hardware host instances
  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  # PLACEMENT CONSTRAINT: Hardened isolation gate ruling that tasks can only launch
  # on server hosts that are running Linux distributions (blocks OS security cross-contamination)
  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.os-type == linux"
  }
}

# 4. Architect the Cost-Optimized Staging ECS Service (The CFO's Cost-Slasher)
resource "aws_ecs_service" "staging_cost_optimized_service" {
  name            = "staging-cost-optimized-service"
  cluster         = aws_ecs_cluster.compute_fleet.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 4

  # STRATEGY PHASE 1: Pack containers tightly on the minimum amount of instances based on memory
  ordered_placement_strategy {
    type  = "binpack"
    field = "memory"
  }

  # STRATEGY PHASE 2: Fall back to packing based on CPU if memory limits are equal
  ordered_placement_strategy {
    type  = "binpack"
    field = "cpu"
  }
}
