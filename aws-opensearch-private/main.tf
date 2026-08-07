# =====================================================================
# CERTIFICATION SCENARIO 31: PRIVATE SECURITY TELEMETRY ARCHITECTURE
# COMPONENT: OPENSEARCH DOMAINS WITH HARDENED PRIVATELINK ENDPOINTS
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Reference Your Existing Private Network Core Boundaries
resource "aws_vpc" "search_vpc" {
  cidr_block           = "10.110.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "Security-Search-Network" }
}

resource "aws_subnet" "private_search_subnet" {
  vpc_id            = aws_vpc.search_vpc.id
  cidr_block        = "10.110.10.0/24"
  availability_zone = "us-east-1a"
  tags                 = { Name = "Private-Search-Hallway" }
}

# 2. Deploy the Hardened Isolated Amazon OpenSearch Domain
resource "aws_opensearch_domain" "log_analytics_engine" {
  domain_name    = "enterprise-security-analytics"
  engine_version = "OpenSearch_2.11" # Modern, secure enterprise search engine standard

  cluster_config {
    instance_type  = "t3.small.search" # Cost-effective laboratory scale analytics node
    instance_count = 1
  }

  # NETWORKING POSTURE: Force the domain to remain entirely inside your private subnets
  vpc_options {
    subnet_ids         = [aws_subnet.private_search_subnet.id]
    security_group_ids = [aws_security_group.search_internal_fw.id]
  }

  encrypt_at_rest {
    enabled = true # Mandates hardware block level encryption on all search volumes
  }

  node_to_node_encryption {
    enabled = true # Cryptographically secures inter-node internal packet traffic
  }

  tags = {
    Layer      = "Private-Telemetry-Search"
    SavedAsset = "True"
  }
}

# 3. Create the Private Local Firewall Restricting Search Ingress
resource "aws_security_group" "search_internal_fw" {
  name        = "opensearch-internal-firewall"
  description = "Accept traffic strictly from our private internal VPC ranges"
  vpc_id      = aws_vpc.search_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.110.0.0/16"] # Limits data plane hits to our internal network core
  }
}

# 4. Deploy the AWS PrivateLink VPC Endpoint for Cross-Account / Cross-Network Access
resource "aws_opensearch_vpc_endpoint" "private_link_access" {
  domain_arn = aws_opensearch_domain.log_analytics_engine.arn

  # BINDING GATEWAY: Injects a secure private network gateway wrapper around your domain
  vpc_options {
    subnet_ids         = [aws_subnet.private_search_subnet.id]
    security_group_ids = [aws_security_group.search_internal_fw.id]
  }
}
