# =====================================================================
# CERTIFICATION SCENARIO 126: AUTONOMOUS SERVERLESS ENGINE SCALING
# COMPONENT: APPLICATION AUTO SCALING CONCURRENCY TARGET TRACKING
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

# 1. Reference Your Foundational ECS Fargate Service Core (From Scenario 121)
data "aws_ecs_cluster" "production_cluster" {
  cluster_name = "enterprise-production-compute-fleet"
}

data "aws_ecs_service" "api_service" {
  cluster_arn  = data.aws_ecs_cluster.production_cluster.id
  service_name = "enterprise-core-backend-api"
}

# 2. Register the Fargate Service as an Elastic Scaling Target Object
resource "aws_appautoscaling_target" "fargate_target" {
  max_capacity       = 20 # Maximum scalable container task ceiling during extreme surges
  min_capacity       = 2  # Baseline cost-efficient task floor during off-peak windows
  resource_id        = "service/${data.aws_ecs_cluster.production_cluster.cluster_name}/${data.aws_ecs_service.api_service.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# 3. Architect the Autonomous Target Tracking Scaling Policy Core
resource "aws_appautoscaling_policy" "cpu_target_tracking" {
  name               = "autonomous-cpu-utilization-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.fargate_target.resource_id
  scalable_dimension = aws_appautoscaling_target.fargate_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.fargate_target.service_namespace

  # TARGET TRACKING CONFIGURATION BLOCK
  target_tracking_scaling_policy_configuration {
    target_value       = 75.0 # Enforce and maintain an aggregate 75% CPU utilization ceiling
    disable_scale_in   = false # Allow full automated down-scaling loops during off-hours

    # Safety cooldown buffers preventing rapid container flapping cycles
    scale_in_cooldown  = 300 # Wait exactly 5 minutes before safely scaling in
    scale_out_cooldown = 60  # React rapidly to surges by waiting only 60 seconds to scale out

    # Uses a highly optimized AWS pre-defined container tracking metric
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
