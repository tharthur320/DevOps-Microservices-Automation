# =====================================================================
# CERTIFICATION SCENARIO 153: PERIMETER NETWORK THREAT INGESTION
# COMPONENT: FIREWALL ALERTS STREAMING VIA KINESIS FIREHOSE TO OPENSEARCH
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

# 1. Reference Your Central Active Network Firewall Appliance (From Scenario 61)
data "aws_networkfirewall_firewall" "perimeter_shield" {
  name = "enterprise-data-center-network-firewall"
}

# 2. Reference Your Existing Private OpenSearch Domain (From Scenario 31)
data "aws_opensearch_domain" "security_analytics" {
  domain_name = "enterprise-security-analytics"
}

# 3. Create the Secure IAM Role Allowing Firehose to Write to Your OpenSearch Domain
resource "aws_iam_role" "firehose_opensearch_role" {
  name = "DataCenter-Firehose-OpenSearchIngestion-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege privileges enabling Firehose to write to OpenSearch indexes
resource "aws_iam_role_policy" "firehose_opensearch_policy" {
  name = "Firehose-OpenSearch-Indexing-Privileges"
  role = aws_iam_role.firehose_opensearch_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "es:ESHttpPost",
          "es:ESHttpPut",
          "es:DescribeElasticsearchDomain",
          "es:DescribeElasticsearchDomains",
          "es:DescribeElasticsearchDomainConfig"
        ]
        Resource = "${data.aws_opensearch_domain.security_analytics.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::enterprise-centralized-siem-logs-2026", # Backup S3 bucket for failed logs
          "arn:aws:s3:::enterprise-centralized-siem-logs-2026/*"
        ]
      }
    ]
  })
}

# 4. Architect the Hardened Real-Time Kinesis Firehose Delivery Stream
resource "aws_kinesis_firehose_delivery_stream" "firewall_opensearch_stream" {
  name        = "aws-network-firewall-alerts-opensearch"
  destination = "opensearch"

  opensearch_configuration {
    role_arn      = aws_iam_role.firehose_opensearch_role.arn
    domain_arn    = data.aws_opensearch_domain.security_analytics.arn
    index_name    = "network-firewall-alerts"
    index_rotation_period = "OneDay" # Auto-rotate active indexes daily to prevent performance lag

    # BUFFERING PARAMETERS: Tunes ingestion velocity and minimizes storage request overhead
    buffering_size      = 5   # Wait until 5 Megabytes of records pool in memory...
    buffering_interval  = 60  # ...or execute bulk indexing pushes every 60 seconds

    # Backup Configuration: Safely drops failed indexing packets into your secure S3 storage locker
    s3_backup_mode = "FailedDocumentsOnly"
    s3_configuration {
      role_arn   = aws_iam_role.firehose_opensearch_role.arn
      bucket_arn = "arn:aws:s3:::enterprise-centralized-siem-logs-2026"
    }
  }
}

# 5. Connect the Real-Time Infiltration Log Configuration onto the Firewall Appliance
resource "aws_networkfirewall_logging_configuration" "firewall_logs_binding" {
  firewall_arn = data.aws_networkfirewall_firewall.perimeter_shield.arn

  logging_configuration {
    log_destination_config {
      log_destination_type = "KinesisDataFirehose"
      log_type             = "ALERT" # Capture deep-packet rule drop and match violations explicitly

      log_destination = {
        deliveryStream = aws_kinesis_firehose_delivery_stream.firewall_opensearch_stream.name
      }
    }
  }
}
