# =====================================================================
# CERTIFICATION SCENARIO 27: AUTOMATED CONTAINER ARTIFACT REPLICATION
# COMPONENT: ECR REPLICATION RULES & CROSS-ACCOUNT PERMISSIONS POLICIES
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Reference Your Central Tooling ECR Code Repository
resource "aws_ecr_repository" "source_repo" {
  name                 = "enterprise-core-microservices"
  image_tag_mutability = "IMMUTABLE" # Prevents attackers from overwriting existing container tags

  image_scanning_configuration {
    scan_on_push = true # Automatically scans container libraries for CVE flaws upon upload
  }
}

# 2. Architect the Centralized Cross-Account Registry Replication Engine
# (This master rule runs in the Source DevOps Tooling Account)
resource "aws_ecr_replication_configuration" "cross_account_sync" {
  replication_configuration {
    rule {
      # INSTRUCTION: Filter and replicate resources matching our repository naming matrix
      repository_filter {
        filter      = "enterprise-core-microservices"
        filter_type = "PREFIX_MATCH"
      }

      # DESTINATION MAPPING: Automatically duplicate the container to the Production Account
      destination {
        region      = "us-east-1"
        registry_id = "888888888888" # The explicit 12-digit physical AWS Production Account ID
      }
    }
  }
}

# 3. DESTINATION BLUEPRINT: Cross-Account ECR Repository Permissions Policy
# (This explicit resource block is deployed inside your target Production Account
# to authorize your local compute clusters to pull the replicated images)
resource "aws_ecr_repository_policy" "production_pull_permissions" {
  repository = "enterprise-core-microservices" # Deployed in target production account

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowProductionFargateTasksToPull"
        Effect = "Allow"
        Principal = {
          # Whitelists strictly the execution roles running your live ECS tasks
          AWS = "arn:aws:iam::888888888888:role/Production-Microservice-DataWorker"
        }
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
      }
    ]
  })
}
