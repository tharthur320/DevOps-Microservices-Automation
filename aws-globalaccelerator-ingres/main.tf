# =====================================================================
# CERTIFICATION SCENARIO 178: GLOBAL INGRESS ACCELERATION & FAILURE RESILIENCE
# COMPONENT: AWS GLOBAL ACCELERATOR ROUTING ANYCAST IP CORRIDORS MULTI-REGION
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

# 1. Reference Your Central Active Regional Application Load Balancer (From Scenario 131)
data "aws_lb" "primary_east_alb" {
  name = "enterprise-production-core-alb"
}

# 2. Provision the Master AWS Global Accelerator Core Engine
resource "aws_globalaccelerator_accelerator" "global_ingress_accelerator" {
  name            = "enterprise-global-ingress-accelerator"
  ip_address_type = "IPV4"
  enabled         = true

  tags = {
    Layer      = "Global-Network-Core"
    SavedAsset = "True"
  }
}

# 3. Deploy the Edge Gateway Port Listener Handling TCP Data Traffic
resource "aws_globalaccelerator_listener" "tcp_listener" {
  accelerator_arn = aws_globalaccelerator_accelerator.global_ingress_accelerator.id
  client_affinity = "NONE" # Distribute requests cleanly based on lowest latency metrics

  port_range {
    from_port = 443
    to_port   = 443
  }
}

# 4. Architect the Multi-Region Endpoint Routing Group
# (This step attaches your regional computing clusters directly to the edge backbone)
resource "aws_globalaccelerator_endpoint_group" "east_coast_endpoints" {
  listener_arn = aws_globalaccelerator_listener.tcp_listener.id
  endpoint_group_region = "us-east-1"

  # INGRESS TRAFFIC SHAPING CONTROLS
  traffic_dial_percentage = 100 # Route 100% of local traffic to this region during normal runtime
  health_check_interval   = 10  # Rapid 10-second polling to catch system drops instantly
  health_check_path       = "/health"
  health_check_port       = 443
  health_check_protocol   = "HTTPS"
  threshold_count         = 2   # Evict the endpoint within 20 seconds if health checks drop

  endpoint_configuration {
    endpoint_id = data.aws_lb.perimeter_alb.arn
    weight      = 128 # Allocates equal balance across primary backend target groups
  }
}

# 5. Output the Fixed Anycast IPs Assigned to Your Virtual Data Center Ingress
output "accelerator_static_ips" {
  value       = aws_globalaccelerator_accelerator.global_ingress_accelerator.ip_sets[0].ip_addresses
  description = "The un-changing global static Anycast IPs to map into your corporate DNS registers"
}
