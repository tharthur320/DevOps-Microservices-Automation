# =====================================================================
# CERTIFICATION SCENARIO 20: AUTOMATED CROSS-ACCOUNT REPOSITORY SYNC
# COMPONENT: CODEBUILD & EVENTBRIDGE FOR REPOSITORIES CLONE MIRRORING
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Deploy the EventBridge Rule Tracking Live CodeCommit Write Operations
resource "aws_cloudwatch_event_rule" "repo_push_monitor" {
  name        = "capture-codecommit-main-branch-pushes"
  description = "Triggers if code changes are checked into the primary repository branch"

  # Event Pattern: Listens explicitly for a reference update on the main branch
  event_pattern = jsonencode({
    "source": ["aws.codecommit"],
    "detail-type": ["CodeCommit Repository State Change"],
    "detail": {
      "event": ["referenceUpdated"],
      "referenceName": ["main"]
    }
  })
}

# 2. Architect the Serverless CodeBuild Mirroring Project
resource "aws_codebuild_project" "repo_mirror_engine" {
  name          = "Enterprise-Core-CrossAccount-RepoMirror"
  description   = "Serverless execution runner that mirrors source history across accounts"
  build_timeout = "5"
  service_role  = aws_iam_role.codebuild_mirror_role.arn

  # Environment: Uses an official, lightweight, hardened Amazon Linux container image
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type = "CODECOMMIT"
    # Target path pointing cleanly back to your central core repository
    location = "https://amazonaws.com"
    
    # Buildspec: The explicit bash command sequence directing git mirror execution
    buildspec = jsonencode({
      version = 0.2
      phases = {
        build = {
          commands = [
            "echo 'Initializing Cross-Account Git Handshake...'",
            "git config --global credential.helper '!aws codecommit credential-helper $@'",
            "git config --global credential.UseHttpPath true",
            "git clone --mirror https://amazonaws.com local-repo",
            "cd local-repo",
            # Mirrors the entire repository history straight to your isolated Production Account ID!
            "git push --mirror https://amazonaws.com"
          ]
        }
      }
    })
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }
}

# 3. Connect EventBridge Directly to Invoke the CodeBuild Mirroring Target
resource "aws_cloudwatch_event_target" "bind_codebuild_target" {
  rule      = aws_cloudwatch_event_rule.repo_push_monitor.name
  target_id = "TriggerServerlessRepoMirror"
  arn       = aws_codebuild_project.repo_mirror_engine.arn
  role_arn  = aws_iam_role.eventbridge_invocation_role.arn # Grants EventBridge right to start the build
}

# 4. Create the Secure IAM Execution Role for the Mirroring Runner
resource "aws_iam_role" "codebuild_mirror_role" {
  name = "DataCenter-CodeBuild-Mirror-Runner"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# 5. Create the Secure IAM Role Allowing EventBridge to Trigger CodeBuild
resource "aws_iam_role" "eventbridge_invocation_role" {
  name = "DataCenter-EventBridge-CodeBuild-Trigger"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}
