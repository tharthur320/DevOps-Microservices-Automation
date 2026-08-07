# =====================================================================
# CERTIFICATION SCENARIO 13: GLOBAL LATENCY OPTIMIZATION & FAILOVER
# COMPONENT: ROUTE 53 LATENCY ROUTING MAPPED TO MULTI-REGION EDGES
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Reference Your Central Domain Namespace Zone
resource "aws_route53_zone" "global_ingress_zone" {
  name    = "://elitedevopsdatacenter.com"
  comment = "Edge Ingress Layer - Multi-Region Latency Switchboard"
}

# 2. Deploy Health Check Monitors for Each Geographical Region Endpoint
resource "aws_route53_health_check" "east_health_check" {
  fqdn              = "://elitedevopsdatacenter.com"
  port              = 80
  type              = "HTTP"
  resource_path     = "/health"
  failure_threshold = "2"  # Mark dead after 2 consecutive failures to accelerate RTO
  request_interval  = "10" # Fast probing interval: check every 10 seconds
}

resource "aws_route53_health_check" "west_health_check" {
  fqdn              = "://elitedevopsdatacenter.com"
  port              = 80
  type              = "HTTP"
  resource_path     = "/health"
  failure_threshold = "2"
  request_interval  = "10"
}

# 3. Architect the US-East Ingress Performance Record (Virginia Hub)
resource "aws_route53_record" "east_latency_record" {
  zone_id = aws_route53_zone.global_ingress_zone.zone_id
  name    = "://elitedevopsdatacenter.com"
  type    = "A"
  ttl     = "30" # Low 30-second TTL forces rapid client-side cache clearing

  # LATENCY POLICY: Automatically catches users with the lowest ping to Virginia
  latency_routing_policy {
    region = "us-east-1"
  }

  set_identifier  = "us-east-datacenter-endpoint"
  health_check_id = aws_route53_health_check.east_health_check.id
  records         = ["192.0.2.75"] # Static target IP of your US-East ALB
}

# 4. Architect the US-West Ingress Performance Record (Oregon Hub)
resource "aws_route53_record" "west_latency_record" {
  zone_id = aws_route53_zone.global_ingress_zone.zone_id
  name    = "://elitedevopsdatacenter.com"
  type    = "A"
  ttl     = "30"

  # LATENCY POLICY: Automatically catches users with the lowest ping to Oregon
  latency_routing_policy {
    region = "us-west-2"
  }

  set_identifier  = "us-west-datacenter-endpoint"
  health_check_id = aws_route53_health_check.west_health_check.id
  records         = ["198.51.100.85"] # Static target IP of your US-West ALB
}
