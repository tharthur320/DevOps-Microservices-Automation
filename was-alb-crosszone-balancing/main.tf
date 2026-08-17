# =====================================================================
# CERTIFICATION SCENARIO 131: TRAFFIC EQUALIZATION & HEALING
# COMPONENT: APPLICATION LOAD BALANCERS ROUTING LEAST-OUTSTANDING-REQUESTS
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

# 1. Reference Your Foundational Infrastructure Network Components (Phase 1 VPC)
data "aws_vpc" "datacenter_vpc" {
  id = "vpc-00000000000000000"
}

# 2. Provision the Highly Available Public Application Load Balancer
resource "aws_lb" "enterprise_alb" {
  name               = "enterprise-production-core-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["sg-00000000000000000"] # Pre-audited perimeter web group
  subnets            = ["subnet-11111111", "subnet-22222222"] # Public ingress zone subnets

  # CRITICAL STRUCTURAL GUARDRAILS: Forces cross-zone packet balancing
  enable_cross_zone_load_balancing = true
  enable_deletion_protection        = false # Explicit override flag for agile portfolio management

  tags = {
    Layer      = "Perimeter-Ingress-Tier"
    SavedAsset = "True"
  }
}

# 3. Architect the Optimized Least-Outstanding-Requests Target Group
resource "aws_lb_target_group" "optimized_target_group" {
  name        = "enterprise-core-balanced-targets"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.datacenter_vpc.id
  target_type = "instance"

  # ADVANCED ROUTING ALGORITHM OVERRIDE
  # Bypasses classic round-robin to balance traffic based on real-time server load
  load_balancing_algorithm_type = "least_outstanding_requests"

  # Ironclad health checking loops protecting downstream application availability
  health_check {
    enabled             = true
    path                = "/health"
    port                = "80"
    protocol            = "HTTP"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3 # Fast eviction: drop unhealthy instances rapidly within 45 seconds
    matcher             = "200"
  }
}

# 4. Deploy the Standard Listener Pipeline Tying the Ingress to the Target
resource "aws_lb_listener" "http_ingress" {
  load_balancer_arn = aws_lb.enterprise_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.optimized_target_group.arn
  }
}
