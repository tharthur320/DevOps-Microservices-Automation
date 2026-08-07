# =====================================================================
# CERTIFICATION SCENARIO 17: REPRODUCTIVE APPLICATION DEPLOYMENTS
# COMPONENT: ELASTIC BEANSTALK ENVIRONMENT SWAPPING VIA ROUTE 53 EDGE
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Provision the Base Elastic Beanstalk Corporate Application Logical Frame
resource "aws_elastic_beanstalk_application" "portal_app" {
  name        = "enterprise-corporate-portal"
  description = "Production monolithic web platform container framework"
}

# 2. Deploy the Active Blue Environment (Currently handling live production load)
resource "aws_elastic_beanstalk_environment" "blue_env" {
  name                = "production-portal-blue"
  application         = aws_elastic_beanstalk_application.portal_app.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.1.2 running Tomcat 9" # Corporate Java baseline stack

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"
  }
}

# 3. Deploy the Isolated Passive Green Environment (Receiving the incoming code update)
resource "aws_elastic_beanstalk_environment" "green_env" {
  name                = "production-portal-green"
  application         = aws_elastic_beanstalk_application.portal_app.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.1.2 running Tomcat 9"

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"
  }
}

# 4. Reference Your Central Corporate DNS Zone
resource "aws_route53_zone" "portal_dns_zone" {
  name = "://elitedevopsenterprise.com"
}

# 5. Connect Route 53 Weighted Edge Routing to Handle Zero-Downtime Blue/Green Swaps
resource "aws_route53_record" "blue_dns_record" {
  zone_id = aws_route53_zone.portal_dns_zone.zone_id
  name    = "://elitedevopsenterprise.com"
  type    = "CNAME"
  ttl     = "60"

  weighted_routing_policy {
    weight = 100 # Initially routes 100% of live sessions to the stable Blue endpoint
  }

  set_identifier = "stable-blue-portal-environment"
  records        = [aws_elastic_beanstalk_environment.blue_env.cname]
}

resource "aws_route53_record" "green_dns_record" {
  zone_id = aws_route53_zone.portal_dns_zone.zone_id
  name    = "://elitedevopsenterprise.com"
  type    = "CNAME"
  ttl     = "60"

  weighted_routing_policy {
    weight = 0 # Holds Green in reserve at 0% until internal sanity testing passes
  }

  set_identifier = "updated-green-portal-environment"
  records        = [aws_elastic_beanstalk_environment.green_env.cname]
}
