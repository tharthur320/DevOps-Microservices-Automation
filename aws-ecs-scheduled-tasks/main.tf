# =====================================================================
# CERTIFICATION SCENARIO 42: BATCH PROCESS AUTOMATION & COST RESILIENCE
# COMPONENT: EVENTBRIDGE CRON RULES DRIVING SERVERLESS ECS TASK RUNS
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Architect the Global Cron Clock (EventBridge Scheduled Event Rule)
resource "aws_cloudwatch_event_rule" "cron_schedule" {
  name                = "enterprise-daily-forensic-audit-schedule"
  description         = "Triggers serverless ledger auditing containers daily at 1:00 AM UTC"
  schedule_expression = "cron(0 1 * * ? *)" # Standard enterprise cron notation mapping
}

# 2. Configure a Secure IAM Role Allowing EventBridge to Launch ECS Containers
resource "aws_iam_role" "eventbridge_ecs_role" {
  name = "DataCenter-EventBridge-ECS-ExecutionTrigger"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge_ecs_execution" {
  name = "EventBridge-ECS-Task-Launch-Privileges"
  role = aws_iam_role.eventbridge_ecs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask"
        ]
        Resource = ["arn:aws:ecs:us-east-1:123456789012:task-definition/secure-web-service:*"] # Your Phase 5 Task Definitions!
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "*"
      }
    ]
  })
}

# 3. Bind the Chronological Rule Directly to Your ECS Serverless Target Group
resource "aws_cloudwatch_event_target" "ecs_batch_target" {
  rule      = aws_cloudwatch_event_rule.cron_schedule.name
  target_id = "LaunchServerlessAuditContainer"
  arn       = "arn:aws:ecs:us-east-1:123456789012:cluster/enterprise-production-microservices" # Existing Phase 5 ECS Cluster!
  role_arn  = aws_iam_role.eventbridge_ecs_role.arn

  ecs_target {
    task_count          = 1
    task_definition_arn = "arn:aws:ecs:us-east-1:123456789012:task-definition/secure-web-service"
    launch_type         = "FARGATE" # Mandates serverless kernel isolated runtime execution

    network_configuration {
      subnets          = ["subnet-11111111"] # Deploys deep inside your private network subnets!
      assign_public_ip = false              # Strict Zero-Trust posture: container remains hidden from the web
      security_groups  = ["sg-00000000000000000"]
    }
  }
}
