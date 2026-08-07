# =====================================================================
# CERTIFICATION SCENARIO 14: GRACEFUL INFRASTRUCTURE DECOMMISSIONING
# COMPONENT: ASG LIFECYCLE HOOKS MAPPED TO SQS TELEMETRY QUEUES
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Deploy a Hardened Amazon SQS Queue to Act as the Automation Mailbox
resource "aws_sqs_queue" "lifecycle_queue" {
  name                      = "datacenter-asg-lifecycle-messages"
  delay_seconds             = 0
  message_retention_seconds = 86400 # Hold telemetry payloads for 24 hours max
  receive_wait_time_seconds = 20    # Enable long pooling to minimize API billing waste
}

# 2. Reference Your Core Data Center Auto Scaling Group Group
# (This binds the hook natively to your existing Phase 3 Autoscaling infrastructure)
resource "aws_autoscaling_group" "production_asg" {
  name                = "enterprise-autoscaling-pool"
  vpc_zone_identifier = ["subnet-11111111", "subnet-22222222"]
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2

  launch_template {
    id      = "lt-00000000000000000"
    version = "$Latest"
  }
}

# 3. Architect the Ironclad Scale-In Lifecycle Hook Buffer
resource "aws_autoscaling_lifecycle_hook" "graceful_shutdown_hook" {
  name                    = "enterprise-connection-draining-hook"
  autoscaling_group_name  = aws_autoscaling_group.production_asg.name
  lifecycle_transition     = "autoscaling:EC2_INSTANCE_TERMINATING" # Intercept scale-in demolition
  default_result          = "ABANDON"                             # Rollback if automation script fails
  heartbeat_timeout       = 600                                   # Pause the instance for exactly 10 minutes (600s)

  # Notification Target: Funnel the machine instance metadata straight into your SQS queue
  notification_target_arn = aws_sqs_queue.lifecycle_queue.arn
  role_arn                = aws_iam_role.asg_notification_role.arn
}

# 4. Create the Secure IAM Notification Access Role for the Autoscaling Engine
resource "aws_iam_role" "asg_notification_role" {
  name = "DataCenter-ASG-Lifecycle-Notifier-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind an IAM policy allowing the ASG engine to drop messages into your secure SQS queue
resource "aws_iam_role_policy" "asg_sqs_write_policy" {
  name = "ASG-SQS-Write-Access"
  role = aws_iam_role.asg_notification_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:SendMessage",
        "sqs:GetQueueAttributes"
      ]
      Resource = aws_sqs_queue.lifecycle_queue.arn
    }]
  })
}
