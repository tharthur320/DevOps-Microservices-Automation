# =====================================================================
# PROJECT: ENTERPRISE MANAGED EDGE ROUTING (AWS ROUTE 53 FAILOVER)
# HIGHLY AVAILABLE DNS SWITCHBOARD WITH HEALTH CHECK INTEGRATION
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Deploy the Primary Public DNS Zone Architecture Namespace
resource "aws_route53_zone" "primary_zone" {
  name    = "elitedevopsenterprise.com" # Root organization domain string
  comment = "Managed core public zone for production edge ingress routing"

  tags = {
    Layer      = "Global-DNS"
    SavedAsset = "True"
  }
}

# 2. Configure an Active Structural Edge Traffic Health Check
resource "aws_route53_health_check" "primary_endpoint_check" {
  fqdn              = "://elitedevopsenterprise.com"
  port              = 80
  type              = "HTTP"
  resource_path     = "/health" # Diagnostic probe pathway
  failure_threshold = "3"       # Mark endpoint dead after 3 consecutive missed pings
  request_interval  = "30"      # Probe the target every 30 seconds

  tags = { Name = "Primary-Edge-HealthCheck" }
}

# 3. Create the Primary Active Route Record (Points to Primary Web Tier)
resource "aws_route53_record" "primary_routing_record" {
  zone_id = aws_route53_zone.primary_zone.zone_id
  name    = "://elitedevopsenterprise.com"
  type    = "A"
  ttl     = "60" # Low 60-second TTL forces rapid client-side cache refreshing

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier  = "primary-compute-node"
  health_check_id = aws_route_health_check.primary_endpoint_check.id
  records         = ["192.0.2.10"] # Simulated static target IP address of primary load balancer
}

# 4. Create the Passive Secondary Backup Record (Points to Disaster Recovery Tier)
resource "aws_route53_record" "secondary_routing_record" {
  zone_id = aws_route53_zone.primary_zone.zone_id
  name    = "://elitedevopsenterprise.com"
  type    = "A"
  ttl     = "60"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "disaster-recovery-node"
  records        = ["198.51.100.20"] # Simulated static target IP address of backup failover tier
}
