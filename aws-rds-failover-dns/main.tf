# =====================================================================
# CERTIFICATION SCENARIO 24: AUTOMATED CROSS-REGION DATABASE FAILOVER
# COMPONENT: ROUTE 53 DATABASE CNAME ABSTRACTING REPLICA PROMOTIONS
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

# 1. Reference Your Central Corporate DNS Zone
resource "aws_route53_zone" "internal_db_zone" {
  name    = "://elitedevopsenterprise.com"
  comment = "Private Data Center Database Routing Subsystem"
}

# 2. Deploy the Primary RDS PostgreSQL Database Cluster (Virginia Hub)
resource "aws_db_instance" "primary_db" {
  identifier           = "production-master-db"
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "15.4"
  instance_class       = "db.t3.micro" # Cost-effective laboratory scale compute allocation
  username             = "dbadmin"
  password             = "HardenedEnterprisePass2026!"
  skip_final_snapshot  = true
  storage_encrypted    = true
  multi_az             = true # Mandates synchronous physical high availability in Virginia

  tags = { Name = "Primary-Master-DB" }
}

# 3. Deploy the Cross-Region Disaster Recovery Read Replica (Oregon Hub)
resource "aws_db_instance" "dr_read_replica" {
  provider            = aws.west # Explicitly targets your secondary Oregon cloud provider link
  identifier          = "disaster-recovery-replica-db"
  replicate_source_db = aws_db_instance.primary_db.arn # Locks replication channel across regions
  instance_class      = "db.t3.micro"
  skip_final_snapshot = true
  storage_encrypted   = true

  tags = {
    Layer      = "Database-Disaster-Recovery"
    SavedAsset = "True"
  }
}

# 4. Architect the Unified Database Entry Pointer Record (CNAME)
resource "aws_route53_record" "db_endpoint_record" {
  zone_id = aws_route53_zone.internal_db_zone.zone_id
  name    = "master.://elitedevopsenterprise.com"
  type    = "CNAME"
  ttl     = "10" # Ultra-low 10-second TTL forces instant client cache invalidation during a cutover

  # INITIAL STATE: Default connection string points directly to the Virginia Primary DB
  records = [aws_db_instance.primary_db.address]
}
