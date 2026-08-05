# =====================================================================
# MASTER PHASE COMPLETION CODE: ENTERPRISE HIGHLY-AVAILABLE NETWORKING,
# PERIMETER FIREWALLS, LOAD BALANCING, AUTOSCALING & ZERO-TRUST SECURITY
# =====================================================================

# 1. AWS Provider Configuration
provider "aws" {
  region = "us-east-1"
}

# ==========================================
# FOUNDATIONAL NETWORK CORE TIER (MULTI-AZ)
# ==========================================

# 2. Architect the Enterprise Root VPC Isolation Network Boundary
resource "aws_vpc" "highly_available_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "Enterprise-HA-VPC"
  }
}

# 3. Create Public Subnets (DMZ Edge Layer) Spanning Multiple Isolated Buildings
resource "aws_subnet" "public_az_a" {
  vpc_id            = aws_vpc.highly_available_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a" # Physical Facility A
  tags = {
    Name = "Public-DMZ-Zone-A"
  }
}

resource "aws_subnet" "public_az_b" {
  vpc_id            = aws_vpc.highly_available_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b" # Physical Facility B
  tags = {
    Name = "Public-DMZ-Zone-B"
  }
}

# 4. Create Private Subnets (Secure App Tier) Spanning Multiple Isolated Buildings
resource "aws_subnet" "private_app_az_a" {
  vpc_id            = aws_vpc.highly_available_vpc.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "us-east-1a" # Physical Facility A
  tags = {
    Name = "Private-App-Zone-A"
  }
}

resource "aws_subnet" "private_app_az_b" {
  vpc_id            = aws_vpc.highly_available_vpc.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "us-east-1b" # Physical Facility B
  tags = {
    Name = "Private-App-Zone-B"
  }
}

# 5. Build an Internet Gateway to Allow Ingress/Egress Edge Routing
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.highly_available_vpc.id
  tags = {
    Name = "Core-Internet-Gateway"
  }
}

# 6. Configure Public Routing Policies
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.highly_available_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "Public-Edge-RouteTable"
  }
}

# 7. Bind Public Subnets Securely to the Public Internet Route Table
resource "aws_route_table_association" "pub_a" {
  subnet_id      = aws_subnet.public_az_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "pub_b" {
  subnet_id      = aws_subnet.public_az_b.id
  route_table_id = aws_route_table.public_rt.id
}

# ==========================================
# EDGE SECURITY AND LOAD BALANCER TIER
# ==========================================

# 8. Load Balancer Public Layer-4 Security Group (Firewall)
resource "aws_security_group" "alb_fw" {
  name        = "alb-perimeter-firewall"
  description = "Filter public traffic entering the environment"
  vpc_id      = aws_vpc.highly_available_vpc.id

  # Allow public web traffic strictly over HTTPS (Port 443) under Least Privilege
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow downstream routing out to application subnets
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ALB-Perimeter-FW"
  }
}

# 9. Deploy the Highly Available Application Load Balancer
resource "aws_lb" "enterprise_alb" {
  name               = "enterprise-public-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_fw.id]
  
  # Bind the ALB to public networks across both physical buildings
  subnets            = [aws_subnet.public_az_a.id, aws_subnet.public_az_b.id]

  tags = {
    Name = "Enterprise-Edge-ALB"
  }
}

# 10. Define the ALB Routing Target Group Container
resource "aws_lb_target_group" "app_target_group" {
  name        = "app-instances-target-pool"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.highly_available_vpc.id
  target_type = "instance"

  # Active Health Checks: Automatically monitor if microservices are alive
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "App-Target-Pool"
  }
}

# ==========================================================
# PACKAGING COMPLETION CODE: AUTOSCALING & ZERO-TRUST
# ==========================================================

# 11. Private App Tier Protective Local Firewall
resource "aws_security_group" "app_internal_fw" {
  name        = "internal-application-firewall"
  description = "Enforce Zero-Trust isolation. Accept traffic ONLY from the edge ALB"
  vpc_id      = aws_vpc.highly_available_vpc.id

  # Inbound Rule: Restrict ingress traffic solely to the Load Balancer's Security Group ID
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_fw.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Internal-App-FW"
  }
}

# 12. Automated Architecture Blueprint (Launch Template) for Server Scaling
resource "aws_launch_template" "app_template" {
  name_prefix   = "secure-app-node-"
  image_id      = "ami-0c7217cdde317cfec" # Official baseline secure Amazon Linux 2023 AMI
  instance_type = "t2.micro"             # Cost-effective, laboratory scale computing bracket

  network_interfaces {
    associate_public_ip_address = false # Enforce network isolation: No public internet access points
    security_groups             = [aws_security_group.app_internal_fw.id]
  }

  # Script payload to instantiate a web status response upon initialization
  user_data = base64encode(<<-EOF
              #!/bin/bash
              sudo dnf install -y httpd
              sudo systemctl start httpd
              sudo systemctl enable httpd
              echo "<h1>Enterprise Microservice Tier: Operational</h1>" > /var/share/nginx/html/index.html
              EOF
  )

  lifecycle {
    create_before_destroy = true
  }
}

# 13. Multi-AZ Highly Available Auto Scaling Infrastructure Pool
resource "aws_autoscaling_group" "ha_asg" {
  name                = "enterprise-autoscaling-pool"
  vpc_zone_identifier = [aws_subnet.private_app_az_a.id, aws_subnet.private_app_az_b.id] # Distribute servers natively across physical buildings
  target_group_arns   = [aws_lb_target_group.app_target_group.arn]                     # Link to Load Balancer routing framework

  launch_template {
    id      = aws_launch_template.app_template.id
    version = "$Latest"
  }

  # Elastic Scale Metrics: Maintain 2 operational nodes at all times, expanding to 4 during load anomalies
  min_size             = 2
  max_size             = 4
  default_cooldown     = 300
  desired_capacity     = 2
  health_check_type    = "ELB"
  force_delete         = true

  tag {
    key                 = "Name"
    value               = "AutoScaled-Secure-AppNode"
    propagate_at_launch = true
  }
}

# 14. Zero-Trust Cryptographic Infrastructure Layer (AWS KMS Custom Key)
resource "aws_kms_key" "db_crypto_key" {
  description             = "Hardware-backed cryptographic master key utilized to enforce multi-tier zero-trust database encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true # Mandatory enterprise posture: Automate cryptographic parameter rotation

  tags = {
    Name = "Database-Storage-KMS-Key"
  }
}
