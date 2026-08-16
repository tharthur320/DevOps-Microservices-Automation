# =====================================================================
# CERTIFICATION SCENARIO 103: TIED-GLOBAL DATA PLANE RESILIENCE
# COMPONENT: AURORA GLOBAL DATABASES WITH CROSS-REGION REPLICATION
# =====================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Primary Region Network Provider (Virginia Hub)
provider "aws" {
  region = "us-east-1"
}

# Secondary Region Network Provider (Oregon Disaster Recovery Hub)
provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

# 1. Provision the Master Global Database Storage Control Plane Container
resource "aws_rds_global_cluster" "global_database_mesh" {
  global_cluster_identifier = "enterprise-global-transaction-mesh"
  engine                    = "aurora-postgresql"
  engine_version            = "15.4"
  database_name             = "enterprise_core_db"
  storage_encrypted         = true # Mandates hardware-level cross-region block encryption
}

# 2. Deploy the Primary Relational Database Cluster (Located in Virginia)
resource "aws_rds_cluster" "primary_cluster" {
  cluster_identifier        = "enterprise-primary-cluster-east"
  engine                    = aws_rds_global_cluster.global_database_mesh.engine
  engine_version            = aws_rds_global_cluster.global_database_mesh.engine_version
  global_cluster_identifier = aws_rds_global_cluster.global_database_mesh.id
  master_username           = "dbadmin"
  master_password           = "HardenedGlobalClusterPass2026!" # Replaced via secure secrets parameters in prod
  db_subnet_group_name      = "enterprise-primary-db-subnets"
  storage_encrypted         = true
  skip_final_snapshot       = true
}

resource "aws_rds_cluster_instance" "primary_instances" {
  count              = 2 # Deploys a primary writer and a local multi-AZ reader for high availability
  identifier         = "east-node-${count.index}"
  cluster_identifier = aws_rds_cluster.primary_cluster.id
  instance_class     = "db.r6g.xlarge" # Memory-optimized gravity instance class matching enterprise loads
  engine             = aws_rds_cluster.primary_cluster.engine
  engine_version     = aws_rds_cluster.primary_cluster.engine_version
}

# 3. Deploy the Companion Secondary Read-Replica Cluster (Located in Oregon)
resource "aws_rds_cluster" "secondary_cluster" {
  provider                  = aws.west # CROSS-REGION BINDING: Force compile inside us-west-2
  cluster_identifier        = "enterprise-dr-cluster-west"
  engine                    = aws_rds_global_cluster.global_database_mesh.engine
  engine_version            = aws_rds_global_cluster.global_database_mesh.engine_version
  global_cluster_identifier = aws_rds_global_cluster.global_database_mesh.id
  db_subnet_group_name      = "enterprise-dr-db-subnets"
  storage_encrypted         = true
  skip_final_snapshot       = true

  depends_on = [aws_rds_cluster_instance.primary_instances]
}

resource "aws_rds_cluster_instance" "secondary_instances" {
  provider           = aws.west
  count              = 1 # Maintained as a warm standby node ready for immediate promotion
  identifier         = "west-node-${count.index}"
  cluster_identifier = aws_rds_cluster.secondary_cluster.id
  instance_class     = "db.r6g.xlarge"
  engine             = aws_rds_cluster.secondary_cluster.engine
  engine_version     = aws_rds_cluster.secondary_cluster.engine_version
}
