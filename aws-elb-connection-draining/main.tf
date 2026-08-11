# =====================================================================
# CERTIFICATION SCENARIO 65: TRAFFIC SHAPING & ZERO-DOWNTIME LIFECYCLES
# COMPONENT: ALB TARGET GROUPS WITH INTEGRATED DEREGISTRATION DELAYS
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

# 1. Reference Your Foundational Data Center VPC Network Infrastructure Core
data "aws_vpc" "datacenter_vpc" {
  id = "vpc-00000000000000000" # References your existing Phase 1 Core VPC ID
}

# 2. Architect the Highly Available Load Balancer Target Group Pool
resource "aws_lb_target_group" "graceful_target_pool" {
  name        = "enterprise-graceful-compute-pool"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.datacenter_vpc.id
  target_type = "instance"

  # TRAFFIC INGRESS SHAPING: Enforce connection draining parameters (Deregistration Delay)
  # Freeze instance termination for exactly 300 seconds (5 minutes) to bleed off requests
  deregistration_delay = 300 

  # Core Health Check Probes ensuring only functional nodes accept traffic
  health_check {
    enabled             = true
    path                = "/health"
    port                = "80"
    protocol            = "HTTP"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3 # Flag un-healthy after 3 consecutive missed probes
  }

  tags = {
    Layer      = "Traffic-Ingress-Bleeding"
    SavedAsset = "True"
  }
}

# 3. Reference Your Reusable Machine Launch Template Core
data "aws_launch_template" "app_template" {
  name = "production-compute-node-baseline"
}

# 4. Deploy the Elastic Auto Scaling Fleet Bound to the Graceful Target Pool
resource "aws_autoscaling_group" "graceful_asg" {
  name                = "enterprise-graceful-autoscaling-fleet"
  vpc_zone_identifier = ["subnet-11111111", "subnet-22222222"] # Isolated private subnet corridors
  min_size            = 2
  max_size            = 5
  desired_capacity    = 2

  # BINDING CORRIDOR: Links your auto-healing servers directly into the draining target group
  target_group_arns = [aws_lb_target_group.graceful_target_pool.arn]

  launch_template {
    id      = data.aws_launch_template.app_template.id
    version = "$Latest"
  }

  # Enforce load balancer health metrics rather than basic EC2 hardware statuses
  health_check_type         = "ELB"
  health_check_grace_period = 300
}
