# =====================================================================
# CERTIFICATION SCENARIO 9: CONTAINER ORCHESTRATION BLUE/GREEN SWAPS
# COMPONENT: AWS CODEDEPLOY SECURING RELEASES FOR ECS FARGATE SERVICES
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Provision the Base CodeDeploy Container Application Model
resource "aws_codedeploy_app" "ecs_app" {
  compute_platform = "ECS" # Enforces the container orchestration compute plane
  name             = "enterprise-container-microservices"
}

# 2. Reference Your Dual Edge Load Balancer Target Group Pools
# (These represent the physical Blue and Green routing hallways behind the ALB)
resource "aws_lb_target_group" "blue_pool" {
  name        = "tg-microservice-blue-pool"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "vpc-00000000000000000" # References your existing core network VPC ID
  target_type = "ip"                    # Required target mapping mode for awsvpc task modes
}

resource "aws_lb_target_group" "green_pool" {
  name        = "tg-microservice-green-pool"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "vpc-00000000000000000"
  target_type = "ip"
}

# 3. Reference Your Public Edge Load Balancer Listener Ingress Gate
resource "aws_lb_listener" "production_traffic_gate" {
  load_balancer_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/mock-alb"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue_pool.arn # Initially defaults routes to Blue
  }
}

# 4. Architect the ECS Blue/Green Deployment Group Controller
resource "aws_codedeploy_deployment_group" "ecs_blue_green" {
  app_name              = aws_codedeploy_app.ecs_app.name
  deployment_group_name = "ecs-microservice-release-channel"
  service_role_arn      = "arn:aws:iam::123456789012:role/MockCodeDeployRole"

  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5 # Retain old containers for 5 mins for emergency rollback capability
    }
  }

  # ECS SPECIFIC INTEGRATION: Core target architecture mapping definitions
  ecs_service {
    cluster_name = "enterprise-production-microservices" # Links directly to your Phase 5 ECS cluster!
    service_name = "enterprise-web-service"
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.production_traffic_gate.arn]
      }

      target_group {
        name = aws_lb_target_group.blue_pool.name
      }

      target_group {
        name = aws_lb_target_group.green_pool.name
      }
    }
  }
}
