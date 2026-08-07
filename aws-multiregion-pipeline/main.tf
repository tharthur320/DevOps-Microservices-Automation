# =====================================================================
# CERTIFICATION SCENARIO 5: MULTI-REGION AUTOMATED DISASTER RECOVERY
# COMPONENT: CROSS-REGION ACTION MAPPING VIA DECLARATIVE CODEPIPELINES
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Establish Pipeline Artifact Buckets for Each Geographical Region
resource "aws_s3_bucket" "east_artifacts" {
  bucket        = "enterprise-pipeline-artifacts-us-east-1-2026"
  force_destroy = true
}

resource "aws_s3_bucket" "west_artifacts" {
  bucket        = "enterprise-pipeline-artifacts-us-west-2-2026"
  force_destroy = true
}

# 2. Architect the Centralized Cross-Region Automation Pipeline
resource "aws_codepipeline" "cross_region_pipeline" {
  name     = "enterprise-global-infrastructure-delivery"
  role_arn = "arn:aws:iam::123456789012:role/MockPipelineRole"

  # Artifact Stores mapping dedicated vaults directly to each target deployment region
  artifact_store {
    location = aws_s3_bucket.east_artifacts.bucket
    type     = "S3"
    region   = "us-east-1"
  }

  artifact_store {
    location = aws_s3_bucket.west_artifacts.bucket
    type     = "S3"
    region   = "us-west-2" # Maps the storage broker space to the backup data center region
  }

  # STAGE 1: INGESTION (Tracks changes in your central repository)
  stage {
    name = "Source"
    action {
      name             = "SourceAction"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        RepositoryName = "DataCenter-Core-Codebase"
        BranchName     = "main"
      }
    }
  }

  # STAGE 2: CROSS-REGION DEPLOYMENT (Launches code across multiple locations)
  stage {
    name = "Deploy-Global-Infrastructure"

    # Action Block A: Local deployment targeting Virginia
    action {
      name            = "Deploy-To-Virginia"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeCloudFormation"
      input_artifacts = ["source_output"]
      version         = "1"
      region          = "us-east-1" # Primary Hub
      configuration = {
        StackName    = "PrimaryVPCStack"
        TemplatePath = "source_output::vpc-core.yaml"
      }
    }

    # Action Block B: CROSS-REGION ACTION MAPPING targeting Oregon
    action {
      name            = "Deploy-To-Oregon"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeCloudFormation"
      input_artifacts = ["source_output"]
      version         = "1"
      region          = "us-west-2" # CROSS-REGION HOOK: Orchestrates steps over Oregon data centers!
      configuration = {
        StackName    = "BackupVPCStack"
        TemplatePath = "source_output::vpc-core.yaml"
      }
    }
  }
}
