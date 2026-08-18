# =====================================================================
# CERTIFICATION SCENARIO 179: HARDENED ANALYTICS CONTAINER BOUNDARIES
# COMPONENT: OPENSEARCH DOMAIN POLICIES MIXED WITH VPC PORT ISOLATION
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

# 1. Reference Your Foundational Infrastructure VPC (Phase 1 Core Network)
data "aws_vpc" "datacenter_vpc" {
  id = "vpc-00000000000000000"
}

# 2. Deploy the Hardened Restrictive Search Cluster Security Group Container
resource "aws_security_group" "search_isolation_sg" {
  name        = "enterprise-opensearch-isolation-fence"
  description = "Strict firewall envelope blocking unapproved network lookup paths to the search tier"
  vpc_id      = data.aws_vpc.datacenter_vpc.id

  # INBOUND RULE: Permit secure HTTPS network transit strictly from your Scenario 139 Lambda role
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = ["sg-22222222222222222"] # Explicitly whitelists the Lambda Ingestion SG!
    description     = "Authorize secure data plane ingress from verified serverless ingester nodes"
  }

  # OUTBOUND BLOCKS: Zero egress rules declared, permanently welding all exit doors shut
}

# 3. Provision the Private Isolated Amazon OpenSearch Service Domain
resource "aws_opensearch_domain" "hardened_search_cluster" {
  domain_name    = "enterprise-core-siem-analytics"
  engine_version = "OpenSearch_2.11"

  cluster_config {
    instance_type          = "m6g.large.search" # Graviton-powered instances for optimized data processing
    instance_count         = 2
    dedicated_master_enabled = false
    zone_awareness_enabled   = true # Spreads data shards across Availability Zones for uptime
    
    zone_awareness_config {
      availability_zone_count = 2
    }
  }

  # STORAGE LAYER HARDENING
  ebs_options {
    ebs_enabled = true
    volume_size = 50
    volume_type = "gp3"
  }

  encrypt_at_rest {
    enabled = true # Mandates hardware-level data-plane storage volume encryption
  }

  node_to_node_encryption {
    enabled = true # Forces cryptographic encryption for internal cluster data syncing
  }

  # PRIVATE NETWORK LAYER HARDENING
  vpc_options {
    subnet_ids         = ["subnet-11111111", "subnet-22222222"] # Deep private subnets (Scenario 31)
    security_group_ids = [aws_security_group.search_isolation_sg.id]
  }

  tags = {
    Layer      = "Security-Analytics-SIEM"
    SavedAsset = "True"
  }
}

# 4. Architect the Hardened Least-Privilege OpenSearch Domain Access Policy
# This resource forces identity validation inside the cluster's internal engine.
resource "aws_opensearch_domain_policy" "cluster_identity_gate" {
  domain_name = aws_opensearch_domain.hardened_search_cluster.domain_name

  access_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "RestrictDataPlaneToLambdaIngestionRole"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::123456789012:role/DataCenter-Lambda-OpenSearchIngestFaultTolerant-Role" # Scenario 139 Worker Role!
        }
        # Grant data plane index manipulation rights exclusively to the ingestion service account
        Action = [
          "es:ESHttpGet",
          "es:ESHttpPost",
          "es:ESHttpPut"
        ]
        Resource = "${aws_opensearch_domain.hardened_search_cluster.arn}/*"
      }
    ]
  })
}
