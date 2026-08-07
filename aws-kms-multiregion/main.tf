# =====================================================================
# CERTIFICATION SCENARIO 18: GLOBAL ZERO-TRUST CRYPTOGRAPHIC FABRIC
# COMPONENT: AWS MULTI-REGION KMS ENCRYPTION PREVENTING REGIONAL LOCKS
# =====================================================================

# Primary Region Provider block (Virginia)
provider "aws" {
  region = "us-east-1"
}

# Secondary Region Provider block (Oregon Disaster Recovery Hub)
provider "aws" {
  alias  = "west_region"
  region = "us-west-2"
}

# 1. Deploy the Primary Customer-Managed KMS Key with Multi-Region Scope Enabled
resource "aws_kms_key" "primary_global_key" {
  description             = "Primary Master Key for Globally Distributed Data Center Encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true # Enforces mandatory corporate automated rotation policies

  # CRITICAL PROPERTY: Instructs HSM hardware to support global duplication
  multi_region = true 

  tags = {
    Layer      = "Global-Cryptographic-Fabric"
    SavedAsset = "True"
  }
}

# 2. Configure a User-Friendly Local Alias Link for the Primary Key
resource "aws_kms_alias" "primary_key_alias" {
  name          = "alias/enterprise-global-core-key"
  target_key_id = aws_kms_key.primary_global_key.key_id
}

# 3. Architect the Cryptographically Identical Replica Key in the DR Region (Oregon)
resource "aws_kms_replica_key" "secondary_replica_key" {
  provider = aws.west_region # Explicitly targets your secondary Oregon cloud provider link

  # BINDING CHANNEL: Pins the replica to pull its exact identity root from the primary key
  primary_key_arn         = aws_kms_key.primary_global_key.arn
  deletion_window_in_days = 7

  tags = {
    Layer      = "DisasterRecovery-Cryptographic-Fabric"
    SavedAsset = "True"
  }
}

# 4. Configure a Matching Local Alias Link in the Secondary Region
resource "aws_kms_alias" "secondary_key_alias" {
  provider      = aws.west_region
  name          = "alias/enterprise-global-core-key"
  target_key_id = aws_kms_replica_key.secondary_replica_key.key_id
}
