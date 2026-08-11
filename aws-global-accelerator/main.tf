# =====================================================================
# CERTIFICATION SCENARIO 48: GLOBAL ANYCAST INGRESS & ACTIVE FAILOVER
# COMPONENT: AWS GLOBAL ACCELERATOR ROUTING ACROSS MULTI-REGION HUBS
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Provision the Enterprise Global Accelerator Engine (Allocates static anycast IPs)
resource "aws_globalaccelerator_accelerator" "global_ingress_gate" {
  name            = "enterprise-worldwide-ingress"
  ip_address_type = "IPV4"
  enabled         = true

  tags = {
    Layer      = "Global-Anycast-Network"
    SavedAsset = "True"
  }
}

# 2. Deploy the Edge Traffic Listener Ingress Port Range
resource "aws_globalaccelerator_listener" "http_listener" {
  accelerator_arn = aws_globalaccelerator_accelerator.global_ingress_gate.id
  client_affinity = "NONE" # Ensures balanced network routing; ignores session persistence locks

  port_range {
    from_port = 80
    to_port   = 80
  }

  port_range {
    from_port = 443
    to_port   = 443
  }

  protocol = "TCP"
}

# 3. Architect the US-East Regional Endpoint Group (Virginia Hub)
resource "aws_globalaccelerator_endpoint_group" "us_east_group" {
  listener_arn                  = aws_globalaccelerator_listener.http_listener.id
  endpoint_group_region         = "us-east-1"
  health_check_interval_seconds = 10 # Rapid 10-second probing intervals to minimize RTO
  health_check_path             = "/health"
  health_check_port             = 80
  health_check_protocol         = "HTTP"
  threshold_count               = 2  # Mark group dead after 2 consecutive failures

  traffic_dial_percentage = 100.0 # Send 100% of local eastern traffic payload here under normal ops

  # BINDING CHANNEL: Ties directly to your existing Phase 2 Application Load Balancer
  endpoint_configuration {
    endpoint_id = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/enterprise-public-alb/5d6c7b8a9012e3f4"
    weight      = 100
  }
}

# 4. Architect the US-West Regional Endpoint Group (Oregon Disaster Recovery Hub)
resource "aws_globalaccelerator_endpoint_group" "us_west_group" {
  listener_arn                  = aws_globalaccelerator_listener.http_listener.id
  endpoint_group_region         = "us-west-2"
  health_check_interval_seconds = 10
  health_check_path             = "/health"
  health_check_port             = 80
  health_check_protocol         = "HTTP"
  threshold_count               = 2

  traffic_dial_percentage = 100.0 # Warm Standby setup ready to capture traffic dynamically

  # BINDING CHANNEL: Ties directly to your secondary Western Application Load Balancer
  endpoint_configuration {
    endpoint_id = "arn:aws:elasticloadbalancing:us-west-2:123456789012:loadbalancer/app/disaster-recovery-alb/7a6b5c4d3e2f1a0b"
    weight      = 100
  }
}
