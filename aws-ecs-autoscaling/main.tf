# =====================================================================
# CERTIFICATION SCENARIO 33: ELASTIC SERVICE CAPACITY SCALING
# COMPONENT: APPLICATION AUTO SCALING ON ECS VIA ALB REQUEST TRACKING
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Register the Amazon ECS Service as a Scalable Application Target
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 10                  # Absolute maximum container node scaling limit
  min_capacity       = 2                   # Absolute minimum high-availability task reservation
  resource_id        = "service/enterprise-production-microservices/enterprise-web-service" # Existing Phase 5 ECS Path
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# 2. Architect the Target-Tracking Scaling Control Policy
resource "aws_appautoscaling_policy" "ecs_alb_tracking_policy" {
  name               = "ecs-alb-request-count-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 1000.0 # Standard threshold metric: Target exactly 1,000 HTTP requests per container
    scale_in_cooldown  = 300    # Cool down for 5 minutes before safely destroying instances to prevent scaling thrashing
    scale_out_cooldown = 60     # Aggressive 60-second scale-out cooldown to rapidly absorb sudden user spikes

    # METRIC TYPE SELECTION: Tracks load balancer request volume metrics natively
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      # References your specific existing Phase 2 ALB routing target pool resource string
      resource_label         = "app/enterprise-public-alb/5d6c7b8a9012e3f4/targetgroup/app-instances-target-pool/7a6b5c4d3e2f1a0b"
    }
  }
}
