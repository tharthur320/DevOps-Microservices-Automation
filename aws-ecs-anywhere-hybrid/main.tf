# =====================================================================
# CERTIFICATION SCENARIO 102: HYBRID CONTAINER CONTROL PLANES
# COMPONENT: ECS ANYWHERE REGISTRATIONS SECURING BARE-METAL SERVERS
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

# 1. Provision the Master Hybrid ECS Container Cluster Core Hub
resource "aws_ecs_cluster" "hybrid_fleet" {
  name = "enterprise-hybrid-compute-fleet"

  setting {
    name  = "containerInsights"
    value = "enabled" # Streams metrics directly to CloudWatch for unified observability
  }
}

# 2. Create the Secure Hybrid External Instance Execution IAM Role
# (Grants the physical server agent structural access tokens to talk to AWS APIs)
resource "aws_iam_role" "ecs_anywhere_role" {
  name = "DataCenter-ECS-Anywhere-ExternalInstance-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" } # SSM acts as the network connection broker
    }]
  })
}

# Attach native policies allowing the hybrid server to register with both SSM and ECS Anywhere
resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  role       = aws_iam_role.ecs_anywhere_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecs_anywhere_core" {
  role       = aws_iam_role.ecs_anywhere_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# 3. Architect the Automated SSM Activation Window (The Key to the Front Gate)
# This resource outputs the registration tokens required to bind on-premises hardware.
resource "aws_ssm_activation" "hybrid_onboarding_gate" {
  name               = "ecs-anywhere-onpremises-activation"
  description        = "Short-lived secure onboarding registration token for bare-metal servers"
  iam_role           = aws_iam_role.ecs_anywhere_role.name
  registration_limit = 5                        # Limit activation to exactly 5 verified local servers
  valid_until        = "2027-12-31T23:59:59Z"   # Enforces a strict expiration boundary on the onboarding token

  tags = {
    Layer      = "Hybrid-Onboarding-Corridor"
    SavedAsset = "True"
  }
}
