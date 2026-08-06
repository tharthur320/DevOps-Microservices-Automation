# =====================================================================
# PROJECT: ENTERPRISE EDGE CRYPTOGRAPHY (AWS ALB TLS TERMINATION)
# HARDENED SSL/TLS BOUNDARY ENFORCING HTTPS AND CRYPTOGRAPHIC OFFLOADING
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Reference Core Network Logical Boundaries Natively
resource "aws_vpc" "app_vpc" {
  cidr_block           = "10.60.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "Cryptographic-Edge-Network" }
}

resource "aws_subnet" "public_subnet_a" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "10.60.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "10.60.2.0/24"
  availability_zone = "us-east-1b"
}

# 2. Deploy a Mock SSL/TLS Certificate Inside AWS Certificate Manager (ACM)
resource "aws_acm_certificate" "tls_cert" {
  domain_name       = "://elitedevopsenterprise.com"
  validation_method = "DNS"

  tags = {
    Layer      = "Cryptographic-Identity"
    SavedAsset = "True"
  }
}

# 3. Create the Edge Security Group Firewall Mandating HTTPS Ingress
resource "aws_security_group" "edge_fw" {
  name   = "edge-tls-firewall"
  vpc_id = aws_vpc.app_vpc.id

  # Inbound Rule: Restrict public ingress traffic strictly to TLS Encrypted Port 443
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 4. Deploy the Public Application Load Balancer
resource "aws_lb" "ssl_alb" {
  name               = "enterprise-tls-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.edge_fw.id]
  subnets            = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
}

# 5. Build the Target Group Destination Pool for Backend Apps
resource "aws_lb_target_group" "backend_pool" {
  name        = "backend-compute-pool"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.app_vpc.id
  target_type = "instance"
}

# 6. Configure the Secure HTTPS Listener Enforcing Cryptographic Termination
resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.ssl_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06" # Mandates modern, secure TLS 1.3/1.2 protocol baselines
  certificate_arn   = aws_acm_certificate.tls_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_pool.arn
  }
}
