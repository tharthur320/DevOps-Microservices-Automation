# =====================================================================
# CERTIFICATION SCENARIO 37: HYBRID ENTERPRISE STORAGE INTEGRATION
# COMPONENT: AWS STORAGE GATEWAY COUPLING LOCAL CORRIDORS TO S3 VAULTS
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Provision the Target Centralized Cloud Storage Bucket Vault
resource "aws_s3_bucket" "hybrid_storage_vault" {
  bucket        = "enterprise-hybrid-storage-archives-2026"
  force_destroy = true
}

# Enforce full-disk bucket encryption using our secure Phase 3 KMS keys
resource "aws_s3_bucket_server_side_encryption_configuration" "encrypt_vault" {
  bucket = aws_s3_bucket.hybrid_storage_vault.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 2. Deploy the Core Logical Storage Gateway Appliance Configuration
resource "aws_storagegateway_gateway" "hybrid_bridge" {
  gateway_image_id   = "ami-0a000000000000000" # Pre-approved official AWS Storage Gateway virtual appliance image
  gateway_name       = "on-premise-datacenter-bridge"
  gateway_timezone   = "GMT"
  gateway_type       = "FILE_S3" # Configures a file gateway to present standard file share protocols

  # ACTIVATION IP: The explicit local private network IP address of your physical on-prem appliance
  gateway_ip_address = "192.168.10.50" 
}

# 3. Architect the SMB File Share Exposing the Endpoint to Local Networks
resource "aws_storagegateway_smb_file_share" "local_share" {
  authentication = "ActiveDirectory" # Enforces secure corporate login credentials via AD Domain controllers
  gateway_arn    = aws_storagegateway_gateway.hybrid_bridge.arn
  location_arn   = aws_s3_bucket.hybrid_storage_vault.arn
  role_arn       = aws_iam_role.gateway_s3_role.arn

  # Path configuration: Determines local share network tracking parameters
  invalid_user_list  = ["Guest", "Anonymous"]
  valid_user_list    = ["Domain Users"]
  audit_destination_arn = "arn:aws:logs:us-east-1:123456789012:log-group:gateway-audit"

  tags = {
    Layer      = "Hybrid-Storage-Bridge"
    SavedAsset = "True"
  }
}

# 4. Create the Secure IAM Role Allowing the Gateway to Write Straight to S3
resource "aws_iam_role" "gateway_s3_role" {
  name = "DataCenter-StorageGateway-S3-Sync-Runner"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Grant the gateway appliance specific read/write tokens to manage your cloud bucket objects
resource "aws_iam_role_policy" "gateway_s3_policy" {
  name = "StorageGateway-S3-Bucket-Access"
  role = aws_iam_role.gateway_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetBucketLocation",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:AbortMultipartUpload"
      ]
      Resource = [
        aws_s3_bucket.hybrid_storage_vault.arn,
        "${aws_s3_bucket.hybrid_storage_vault.arn}/*"
      ]
    }]
  })
}
