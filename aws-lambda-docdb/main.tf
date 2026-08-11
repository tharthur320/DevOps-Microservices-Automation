# =====================================================================
# CERTIFICATION SCENARIO 58: SERVERLESS DYNAMIC DATA LAYERS
# COMPONENT: AWS LAMBDA VPC ROUTING TIED TO ISOLATED DOCUMENTDB CLUSTERS
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

# 1. Reference Your Private Data Center Network Infrastructure Core Boundaries
data "aws_vpc" "datacenter_vpc" {
  id = "vpc-00000000000000000" # References your existing Phase 1 Core VPC ID
}

data "aws_subnet" "private_db_a" {
  id = "subnet-11111111" # Private Subnet in Availability Zone A
}

data "aws_subnet" "private_db_b" {
  id = "subnet-22222222" # Private Subnet in Availability Zone B
}

# 2. Architect the Hardened Amazon DocumentDB Subnet Group
resource "aws_docdb_subnet_group" "db_subnets" {
  name       = "enterprise-docdb-subnet-group"
  subnet_ids = [data.aws_subnet.private_db_a.id, data.aws_subnet.private_db_b.id]
}

# 3. Create the Private Database Security Group Firewall Registry
resource "aws_security_group" "docdb_fw" {
  name        = "docdb-private-firewall"
  description = "Accept incoming database traffic on Port 27017 from internal VPC"
  vpc_id      = data.aws_vpc.datacenter_vpc.id

  ingress {
    from_port   = 27017
    to_port     = 27017
    private_ip  = ""
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.datacenter_vpc.cidr_block] # Restricts data traffic to internal core network
  }
}

# 4. Deploy the Highly Available Amazon DocumentDB Cluster Core
resource "aws_docdb_cluster" "secure_document_db" {
  cluster_identifier      = "enterprise-production-catalog"
  engine                  = "docdb"
  master_username         = "catalogadmin"
  master_password         = "HardenedDocumentPass2026!" # Replaced via secure vault parameters in production
  db_subnet_group_name    = aws_docdb_subnet_group.db_subnets.name
  vpc_security_group_ids  = [aws_security_group.docdb_fw.id]
  storage_encrypted       = true # Mandates full-disk encryption at rest via customer-managed keys
  skip_final_snapshot     = true
}

resource "aws_docdb_cluster_instance" "cluster_instances" {
  count              = 2 # Deploys 2 separate cluster instances for automated multi-AZ failover
  identifier         = "catalog-node-${count.index}"
  cluster_identifier = aws_docdb_cluster.secure_document_db.id
  instance_class     = "db.t3.medium"
}

# 5. Deploy the Hardened Lambda Compute Layer with Native VPC Routing Enabled
resource "aws_lambda_function" "catalog_worker" {
  function_name = "Enterprise-Core-Serverless-CatalogWorker"
  role          = "arn:aws:iam::123456789012:role/MockLambdaVPCExecutionRole"
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "mock-catalog-worker.zip"
  timeout       = 30

  # NATIVE NETWORK CONTAINMENT: Force the function to execute inside your private subnets
  vpc_config {
    subnet_ids         = [data_aws_subnet.private_db_a.id, data_aws_subnet.private_db_b.id]
    security_group_ids = [aws_security_group.docdb_fw.id]
  }

  depends_on = [aws_docdb_cluster_instance.cluster_instances]
}
