# =====================================================================
# CERTIFICATION SCENARIO 29: GLOBAL CACHE PERSISTENCE & DR AUTOMATION
# COMPONENT: AMAZON ELASTICACHE FOR REDIS GLOBAL REPLICATION GROUPS
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

# 1. Deploy the Primary ElastiCache Replication Group (Virginia Data Center)
resource "aws_elasticache_replication_group" "primary_cluster" {
  replication_group_id        = "enterprise-cache-primary"
  description                 = "Primary high-performance core caching cluster"
  node_type                   = "cache.t3.medium"
  num_cache_clusters          = 2
  parameter_group_name        = "default.redis7"
  port                        = 6379
  multi_az_enabled            = true # Synchronous local high-availability
  automatic_failover_enabled  = true
  at_rest_encryption_enabled  = true
  transit_encryption_enabled  = true
}

# 2. Architect the Universal Multi-Region Global Replication Core Frame
resource "aws_elasticache_global_replication_group" "global_cache_mesh" {
  global_replication_group_id_suffix = "enterprise-global-cache"
  primary_replication_group_id        = aws_elasticache_replication_group.primary_cluster.id
}

# 3. Deploy the Disaster Recovery Secondary Failover Cluster (Oregon Data Center)
resource "aws_elasticache_replication_group" "secondary_failover_cluster" {
  provider                    = aws.west # Targets your secondary Oregon cloud environment
  replication_group_id        = "enterprise-cache-secondary"
  description                 = "Disaster recovery active-passive backup caching pool"
  
  # CROSS-REGION BINDING CHANNEL: Anchors this cluster to pull data from the global core frame
  global_replication_group_id = aws_elasticache_global_replication_group.global_cache_mesh.global_replication_group_id
  
  node_type                   = "cache.t3.medium"
  num_cache_clusters          = 2
  parameter_group_name        = "default.redis7"
  port                        = 6379
  multi_az_enabled            = true
  automatic_failover_enabled  = true
  at_rest_encryption_enabled  = true
  transit_encryption_enabled  = true

  depends_on = [aws_elasticache_global_replication_group.global_cache_mesh]
}
