# =====================================================================
# CERTIFICATION SCENARIO 3: AUTOMATED PIPELINE APPROVAL GATES
# COMPONENT: SECURE CODEPIPELINE MANUAL SIGNOFFS WITH SLACK INTEGRATION
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Deploy the Primary Amazon SNS Notification Topic
resource "aws_sns_topic" "pipeline_approvals" {
  name = "enterprise-production-pipeline-approvals"
}

# 2. Architect an AWS Lambda Function to Formulate and Send Slack Payloads
resource "aws_lambda_function" "slack_notifier" {
  function_name = "Enterprise-Pipeline-SlackNotifier"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x" # Highly reliable serverless runtime environment

  # Injected script payload translating cloud event data into chat app blocks
  inline_policy {
    name = "LambdaLogPolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Effect   = "Allow"
        Resource = "*"
      }]
    })
  }

  environment {
    variables = {
      SLACK_WEBHOOK_URL = "https://slack.com" # Secured via corporate secrets in production
    }
  }
}

# 3. Create a Secure IAM Execution Role for the Serverless Function
resource "aws_iam_role" "lambda_exec_role" {
  name = "Pipeline-SlackNotifier-ExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# 4. Subscribe the Lambda Function Natively to the Amazon SNS Approval Topic
resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = aws_sns_topic.pipeline_approvals.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notifier.arn
}

# Allow SNS to Invoke the Lambda Function
resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notifier.function_name
  principal     = "://amazonaws.com"
  source_arn    = aws_sns_topic.pipeline_approvals.arn
}
