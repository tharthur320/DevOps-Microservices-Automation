# =====================================================================
# CERTIFICATION SCENARIO 66: SERVERLESS LOG ANALYTICS & AUDITING
# COMPONENT: S3 SERVER ACCESS LOGGING MAPPED TO ATHENA SQL ENGINE SCHEMAS
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

# 1. Provision an Isolated S3 Storage Vault to Hold Raw Server Access Logs
resource "aws_s3_bucket" "access_log_vault" {
  bucket        = "enterprise-datacenter-server-access-logs-2026"
  force_destroy = true
}

# Enforce access control rules allowing the native logging service to write to the vault
resource "aws_s3_bucket_ownership_controls" "logs_ownership" {
  bucket = aws_s3_bucket.access_log_vault.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl_v2" "logs_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.logs_ownership]
  bucket     = aws_s3_bucket.access_log_vault.id
  acl        = "log-delivery-write" # Grants write tokens to the AWS log delivery plane
}

# 2. Deploy the Primary Production Data S3 Bucket with Access Logging Armed
resource "aws_s3_bucket" "production_data_vault" {
  bucket        = "enterprise-core-production-confidential-data-2026"
  force_destroy = false
}

resource "aws_s3_bucket_logging" "enable_logging" {
  bucket        = aws_s3_bucket.production_data_vault.id
  target_bucket = aws_s3_bucket.access_log_vault.id
  target_prefix = "data-plane-access-records/" # Prefixes group text blocks cleanly for Athena partitioning
}

# 3. Provision the Serverless Athena Analytics Database Core Frame
resource "aws_athena_database" "security_audit_db" {
  name   = "enterprise_s3_access_audit_db"
  bucket = aws_s3_bucket.access_log_vault.bucket # Primary query workspace bucket destination
}

# 4. Architect the Athena Table Creation Schema Query Definition
# This text block writes out the structural DDL SQL statement needed to translate
# raw space-delimited S3 server logs into an indexed, searchable column database.
resource "aws_athena_named_query" "create_audit_table_schema" {
  name        = "CreateS3AccessLogTableSchema"
  database    = aws_athena_database.security_audit_db.name
  description = "Deploys a structured column schema mapping over the raw S3 data-plane access logs"

  query = <<EOF
CREATE EXTERNAL TABLE IF NOT EXISTS ${aws_athena_database.security_audit_db.name}.s3_access_logs (
    BucketOwner STRING,
    Bucket STRING,
    RequestDateTime STRING,
    RemoteIP STRING,
    Requester STRING,
    RequestID STRING,
    Operation STRING,
    Key STRING,
    RequestURI_OperationSTRING STRING,
    HTTPStatus INT,
    ErrorCode STRING,
    BytesSent BIGINT,
    ObjectSize BIGINT,
    TotalTime INT,
    TurnAroundTime INT,
    Referrer STRING,
    UserAgent STRING,
    VersionId STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
WITH SERDEPROPERTIES (
    'input.regex' = '([^ ]*) ([^ ]*) \\[(.*?)\\] ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) (\"[^\"]*\"|-) (-|[0-9]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) (\"[^\"]*\"|-) ([^ ]*)'
)
LOCATION 's3://${aws_s3_bucket.access_log_vault.bucket}/data-plane-access-records/';
EOF
}

# 5. Pre-Save a Practical Incident Response Query to Instantly Detect HTTP 403 Access Denied Threats
resource "aws_athena_named_query" "detect_unauthorized_access_attempts" {
  name        = "ForensicSearchUnauthorizedAccess"
  database    = aws_athena_database.security_audit_db.name
  description = "Queries the log ledger to track malicious source IPs throwing HTTP 403 Forbidden errors"

  query = <<EOF
SELECT RemoteIP, RequestDateTime, Key, Operation, HTTPStatus 
FROM ${aws_athena_database.security_audit_db.name}.s3_access_logs 
WHERE HTTPStatus = 403 
ORDER BY RequestDateTime DESC 
LIMIT 100;
EOF
}
