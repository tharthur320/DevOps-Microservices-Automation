# =====================================================================
# CERTIFICATION SCENARIO 86: CONTINUOUS DELIVERY CIRCUIT BREAKERS
# COMPONENT: CODEPIPELINE INTEGRATED WITH REAL-TIME ANOMALY ROLLBACKS
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

# 1. Deploy the CloudWatch Metric Alarm Tracking Production API Errors
resource "aws_cloudwatch_metric_alarm" "api_error_alarm" {
  alarm_name          = "Production-API-High-Error-Rates"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_Target_5XX_Count" # Tracks internal microservice crash codes
  namespace           = "AWS/ApplicationELB"
  period              = "60" # Snapshot system exceptions every 60 seconds
  statistic           = "Sum"
  threshold           = "10" # Trigger if more than 10 bad responses throw within a single minute
  alarm_description   = "Circuit breaker tracking production microservice exceptions during deployment windows."

  dimensions = {
    LoadBalancer = "app/enterprise-public-alb/5d6c7b8a9012e3f4"
  }
}

# 2. Architect the Enterprise Continuous Delivery Pipeline with Automated Gates
resource "aws_codepipeline" "gated_delivery_pipeline" {
  name     = "enterprise-gated-microservice-pipeline"
  role_arn = "arn:aws:iam::123456789012:role/MockPipelineRole"

  artifact_store {
    location = "enterprise-ecs-continuous-delivery-vault-2026" # Reuses your Scenario 49 artifact vault!
    type     = "S3"
  }

  # STAGE 1: INGESTION CODE COMMIT CHECK
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

  # STAGE 2: CONTAINER COMPILING STAGE (Reuses your Scenario 49 CodeBuild engine)
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
        ProjectName = "Enterprise-Core-Container-Builder"
      }
    }
  }

  # STAGE 3: GATED DEPLOYMENT WITH AUTOMATED INCIDENT CIRCUIT BREAKERS
  stage {
    name = "Deploy"
    action {
      name            = "DeployToECS"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      input_artifacts = ["build_output"]
      version         = "1"
      configuration = {
        ApplicationName                = "enterprise-container-microservices"
        DeploymentGroupName            = "ecs-microservice-release-channel"
        TaskDefinitionTemplateArtifact = "build_output"
        AppSpecTemplateArtifact        = "build_output"
      }
    }
  }
}
