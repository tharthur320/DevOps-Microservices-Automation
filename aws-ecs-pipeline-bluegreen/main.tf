# =====================================================================
# CERTIFICATION SCENARIO 49: CONTINUOUS CONTAINER SERVICE DELIVERY
# COMPONENT: MULTI-STAGE CODEPIPELINES DRIVING AUTOMATED RELEASE GATES
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Provision the Pipeline Artifact Storage Vault S3 Bucket
resource "aws_s3_bucket" "pipeline_vault" {
  bucket        = "enterprise-ecs-continuous-delivery-vault-2026"
  force_destroy = true
}

# 2. Deploy the Serverless CodeBuild Project Compiling Docker Images
resource "aws_codebuild_project" "container_builder" {
  name          = "Enterprise-Core-Container-Builder"
  service_role  = "arn:aws:iam::123456789012:role/MockCodeBuildRole"
  build_timeout = "20"

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true # Required to execute native Docker daemon commands inside the builder
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = jsonencode({
      version = 0.2
      phases = {
        pre_build = {
          commands = ["echo Logging into Amazon ECR...", "aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ://amazonaws.com"]
        }
        build = {
          commands = ["docker build -t enterprise-core-microservices:latest .", "docker tag enterprise-core-microservices:latest ://amazonaws.com/enterprise-core-microservices:latest"]
        }
        post_build = {
          commands = ["docker push ://amazonaws.com/enterprise-core-microservices:latest", "printf '[{\"name\":\"production-app\",\"imageUri\":\"://amazonaws.com/enterprise-core-microservices:latest\"}]' > imagedefinitions.json"]
        }
      }
      artifacts = {
        files = ["imagedefinitions.json", "appspec.yaml"]
      }
    })
  }

  artifacts {
    type = "CODEPIPELINE"
  }
}

# 3. Architect the Enterprise Continuous Delivery CodePipeline
resource "aws_codepipeline" "container_delivery_pipeline" {
  name     = "enterprise-container-delivery-pipeline"
  role_arn = "arn:aws:iam::123456789012:role/MockPipelineRole"

  artifact_store {
    location = aws_s3_bucket.pipeline_vault.bucket
    type     = "S3"
  }

  # STAGE 1: INGESTION (Tracks your secure corporate CodeCommit repository)
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

  # STAGE 2: COMPILING (Invokes serverless Docker building containers)
  stage {
    name = "Build"
    action {
      name             = "BuildContainerImage"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.container_builder.name
      }
    }
  }

  # STAGE 3: BLUE/GREEN DEPLOYMENT (Atomic target swapping via CodeDeploy)
  stage {
    name = "Deploy"
    action {
      name            = "DeployToECS"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS" # Native integration managing Blue/Green switches
      input_artifacts = ["build_output"]
      version         = "1"
      configuration = {
        ApplicationName                = "enterprise-container-microservices" # Existing Scenario 9 App Name!
        DeploymentGroupName            = "ecs-microservice-release-channel"   # Existing Scenario 9 Group!
        TaskDefinitionTemplateArtifact = "build_output"
        AppSpecTemplateArtifact        = "build_output"
      }
    }
  }
}
