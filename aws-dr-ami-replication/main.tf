# =====================================================================
# CERTIFICATION SCENARIO 8: AUTOMATED CROSS-REGION DATA PROTECTION
# COMPONENT: EVENTBRIDGE & LAMBDA FOR PROGRAMMATIC CROSS-REGION COPIES
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Deploy the EventBridge Rule Catching Image Snapshot Status Completions
resource "aws_cloudwatch_event_rule" "ami_creation_monitor" {
  name        = "capture-successful-ami-creations"
  description = "Triggers if an Amazon Machine Image transitions into an operational status"

  # Event Pattern: Listens explicitly for the native EC2 AMI state change status of "available"
  event_pattern = jsonencode({
    "source": ["aws.ec2"],
    "detail-type": ["EC2 AMI State Change"],
    "detail": {
      "state": ["available"]
    }
  })
}

# 2. Architect the Serverless Multi-Region Replication Function (AWS Lambda)
resource "aws_lambda_function" "ami_replicator" {
  function_name = "Enterprise-Core-AMI-CrossRegionReplicator"
  role          = aws_iam_role.lambda_replication_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"

  # Inline programmatic execution script modeling the CopyImage API action routing
  inline_policy {
    name = "LambdaAMICopyPolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "ec2:CopyImage",
            "ec2:DescribeImages"
          ]
          Resource = "*"
        },
        {
          Effect   = "Allow"
          Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
          Resource = "*"
        }
      ]
    })
  }

  # Hardcoded destination variables informing the API precisely where to ship the payload
  environment {
    variables = {
      DESTINATION_REGION = "us-west-2" # Directing the data duplication pipeline to Oregon
    }
  }
}

# 3. Securely Bind the EventBridge Catching Mechanism to the Lambda Target Group
resource "aws_cloudwatch_event_target" "bind_lambda_target" {
  rule      = aws_cloudwatch_event_rule.ami_creation_monitor.name
  target_id = "TriggerCrossRegionAMICopy"
  arn       = aws_lambda_function.ami_replicator.arn
}

# 4. Create the Secure IAM Execution Role for the Replication Automation Engine
resource "aws_iam_role" "lambda_replication_role" {
  name = "DataCenter-AMI-Replication-Runner"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Allow EventBridge to Invoke the Lambda Function Natively
resource "aws_lambda_permission" "allow_eventbridge_execution" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ami_replicator.function_name
  principal     = "://amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ami_creation_monitor.arn
}
