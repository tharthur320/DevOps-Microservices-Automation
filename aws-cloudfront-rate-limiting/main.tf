# =====================================================================
# CERTIFICATION SCENARIO 23: EDGE TRAFFIC HARDENING & BOT MITIGATION
# COMPONENT: CLOUDFRONT CDN & WAFV2 ENFORCING AUTOMATED RATE LIMITS
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Architect the Edge WAFv2 Web ACL with a Custom Rate-Limiting Rule
resource "aws_wafv2_web_acl" "edge_rate_shield" {
  name        = "edge-rate-limiting-shield"
  description = "Edge threat firewall blocking volumetric DDoS and scraping botnets"
  
  # CRITICAL PERFORMANCE CONSTRAINT: Must be CLOUDFRONT for edge deployments
  scope       = "CLOUDFRONT" 

  default_action {
    allow {} # Allow safe baseline traffic through to evaluate the rate logic
  }

  rule {
    name     = "EnforceCorporateRateLimits"
    priority = 1

    action {
      block {} # INSTRUCTION: Instantly drop traffic if the threshold is crossed
    }

    statement {
      rate_based_statement {
        limit              = 100 # Maximum allowed requests per individual IP inside 5 minutes
        aggregate_key_type = "IP"  # Evaluates the unique source IP address of incoming packets
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CorporateRateLimitMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "EdgeRateShieldGlobalMetric"
    sampled_requests_enabled   = true
  }
}

# 2. Deploy the Global CloudFront Content Delivery Network (CDN) Distribution
resource "aws_cloudfront_distribution" "cdn_edge" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Production Enterprise Data Center Edge Ingress Distribution"
  
  # BINDING ACCESS CHANNEL: Secures the entry gates via your rate-limiting Web ACL ID
  web_acl_id          = aws_wafv2_web_acl.edge_rate_shield.arn

  # Origin Configuration: Points the CDN straight to your public Application Load Balancer
  origin {
    domain_name = "://amazonaws.com" # Existing Phase 2 Load Balancer
    origin_id   = "ALB-Core-Origin"

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "https-only" # Mandates encrypted transport layer security
      origin_ssl_protocols     = ["TLSv1.2", "TLSv1.3"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "ALB-Core-Origin"

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https" # Automatically upgrades unencrypted traffic
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Global Caching Footprint Boundaries
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Layer      = "Global-Edge-Infiltration-Shield"
    SavedAsset = "True"
  }
}
