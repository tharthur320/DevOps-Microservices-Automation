# =====================================================================
# CERTIFICATION SCENARIO 161: GLOBAL EDGE ACCELERATION PERIMETERS
# COMPONENT: CLOUDFRONT CACHE POLICIES EQUIPPED WITH ORIGIN SHIELDING
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

# 1. Reference Your Foundational Public Application Load Balancer Ingress (From Scenario 131)
data "aws_lb" "perimeter_alb" {
  name = "enterprise-production-core-alb"
}

# 2. Architect the Optimized Advanced API Ingress Cache Policy Control
resource "aws_cloudfront_cache_policy" "api_optimized_cache" {
  name        = "enterprise-api-optimized-cache-policy"
  comment     = "Fences explicit cache keys to streamline high-frequency read requests"
  default_ttl = 60
  max_ttl     = 300
  min_ttl     = 10

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    # CACHE KEY BOUNDARIES: Fine-tunes cache uniqueness to prevent security cross-talk
    cookies {
      cookie_behavior = "none"
    }
    
    headers {
      header_behavior = "whitelist"
      headers {
        items = ["Accept", "Accept-Language", "x-enterprise-client-tier"]
      }
    }

    query_strings {
      query_string_behavior = "whitelist"
      query_strings {
        items = ["transaction_type", "currency"]
      }
    }
  }
}

# 3. Deploy the Global CloudFront Content Delivery Network Core
resource "aws_cloudfront_distribution" "global_api_accelerator" {
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All" # Deploy across all global edge nodes for absolute performance
  staging             = false

  # ALIGN WITH GLOBAL SCOPE THREAT SHIELDS (From Scenario 155)
  web_acl_id = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/enterprise-global-cloudfront-xss-shield/a1b2c3d4"

  origin {
    domain_name = data.aws_lb.perimeter_alb.dns_name
    origin_id   = "primary-regional-alb-origin"

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "https-only" # Mandates ironclad data plane flight encryption
      origin_ssl_protocols     = ["TLSv1.2", "TLSv1.3"]
      origin_keepalive_timeout = 60
      origin_read_timeout      = 30
    }

    # HARDENED EXAM MAPPING: CENTRALIZED COMPUTE SHIELDING TIER
    # Funnels cache misses through N. Virginia to flatten backend traffic waves
    origin_shield {
      enabled              = true
      origin_shield_region = "us-east-1"
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "primary-regional-alb-origin"
    viewer_protocol_policy = "redirect-to-https"

    # Dynamic binding to our specialized cache keys policy
    cache_policy_id = aws_cloudfront_cache_policy.api_optimized_cache.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true # Replaced with custom domain ACM tokens in live environments
  }

  tags = {
    Layer      = "Global-Ingress-Acceleration"
    SavedAsset = "True"
  }
}
