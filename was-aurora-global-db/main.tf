# =====================================================================
# PROJECT: ENTERPRISE REGIONAL DISASTER RECOVERY (AMAZON AURORA GLOBAL DB)
# GLOBAL CRADLE FOR SECURING MULTI-CONTINENT CRYPTOGRAPHIC DATA PERSISTENCE
# =====================================================================

provider "aws" {
  alias  = "primary_region"
  region = "us-east-1" # Primary live operational hub (Virginia)
}

provider "aws" {
  alias  = "secondary_region"
  region = "us-west-2" # High-speed backup disaster recovery hub (Oregon)
}

# 1. Architect the Universal Multi-Region Global Database Frame
resource "aws_rds_global_cluster" "global_db" {
  provider                  = aws.primary_region
  global_cluster_identifier = "enterprise-global-core-database"
  engine                    = "aurora-postgresql"
  engine_version            = "15.4"
  storage_encrypted         = true # Mandates cryptographic hardware block locks across all regions
}

# 2. Deploy the Primary DB Cluster Infrastructure (Region A)
resource "aws_rds_cluster" "primary_cluster" {
  provider                  = aws.primary_region
  cluster_identifier        = "primary-cluster-us-east"
  engine                    = aws_rds_global_cluster.global_db.engine
  engine_version            = aws_rds_global_cluster.global_db.engine_version
  global_cluster_identifier = aws_rds_global_cluster.global_db.id
  master_username           = "dbadmin"
  master_password           = "SecureEnterprisePass2026!" # Replaced with vault variables in production
  db_subnet_group_name      = "default"
  storage_encrypted         = true
  skip_final_snapshot       = true
}

resource "aws_rds_cluster_instance" "primary_instance" {
  provider           = aws.primary_region
  cluster_identifier = aws_rds_cluster.primary_cluster.id
  instance_class     = "db.r6g.large" # Memory-optimized database class parameters
  engine             = aws_rds_cluster.primary_cluster.engine
  engine_version     = aws_rds_cluster.primary_cluster.engine_version
}

# 3. Deploy the Failover Storage Cluster Infrastructure (Region B)
resource "aws_rds_cluster" "secondary_cluster" {
  provider                  = aws.secondary_region
  cluster_identifier        = "secondary-failover-cluster-us-west"
  engine                    = aws_rds_global_cluster.global_db.engine
  engine_version            = aws_rds_global_cluster.global_db.engine_version
  global_cluster_identifier = aws_rds_global_cluster.global_db.id
  db_subnet_group_name      = "default"
  storage_encrypted         = true
  skip_final_snapshot       = true

  depends_on = [aws_rds_cluster_instance.primary_instance] # Structural safeguard mapping order
}

resource "aws_rds_cluster_instance" "secondary_instance" {
  provider           = aws.secondary_region
  cluster_identifier = aws_rds_cluster.secondary_cluster.id
  instance_class     = "db.r6g.large"
  engine             = aws_rds_cluster.secondary_cluster.engine
  engine_version     = aws_rds_cluster.secondary_cluster.engine_version
}
