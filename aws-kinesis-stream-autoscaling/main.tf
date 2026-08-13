# =====================================================================
# CERTIFICATION SCENARIO 78: STREAMING CAPACITY AUTO-SCALING
# COMPONENT: EVENTBRIDGE ALARMS TRIGGERS AUTOMATED KINESIS STREAM SPLITS
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

# 1. Deploy the Central High-Volume Amazon Kinesis Data Stream Ingestion Core
resource "aws_kinesis_stream" "telemetry_ingest_stream" {
  name             = "enterprise-production-telemetry-ingest"
  shard_count      = 2             # Initial cost-effective data channel allocation base
  retention_period = 24            # Retain logs for 24 hours inside stream shards
  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes"
  ]
  stream_mode_details {
    stream_mode = "PROVISIONED"    # Managed capacity constraints ideal for scenario auto-scaling checks
  }
}

# 2. Deploy the CloudWatch Metric Alarm Monitoring Consumer Processing Lag
resource "aws_cloudwatch_metric_alarm" "iterator_age_alarm" {
  alarm_name          = "CRITICAL-KINESIS-CONSUMER-ITERATOR-AGE-SPIKE"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "GetRecords.IteratorAgeMilliseconds"
  namespace           = "AWS/Kinesis"
  period              = "60" # Check consumer lag metrics every 60 seconds
  statistic           = "Maximum"
  threshold           = "300000" # Fire the alert if consumer lag crosses 5 minutes (300k ms)
  alarm_description   = "Triggers real-time scaling if downstream application consumers fall behind data injection loops."

  dimensions = {
    StreamName = aws_kinesis_stream.telemetry_ingest_stream.name
  }
}

# 3. Create the Secure IAM Execution Role for the Stream Auto-Scaler Engine
resource "aws_iam_role" "stream_scaler_role" {
  name = "DataCenter-Kinesis-StreamScaler-ExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit least-privilege stream read and shard allocation update tokens to the role
resource "aws_iam_role_policy" "stream_scaler_privileges" {
  name = "Lambda-Kinesis-Shard-Allocation-Privileges"
  role = aws_iam_role.stream_scaler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:UpdateShardCount",
          "kinesis:DescribeStreamSummary",
          "kinesis:DescribeStream"
        ]
        Resource = aws_kinesis_stream.telemetry_ingest_stream.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      }
    ]
  })
}

# 4. Deploy the Serverless Stream Auto-Scaling Script (AWS Lambda)
resource "aws_lambda_function" "stream_autoscaler_worker" {
  function_name = "Enterprise-Core-KinesisStream-Autoscaler"
  role          = aws_iam_role.stream_scaler_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "mock-stream-scaler.zip"
  timeout       = 30

  environment {
    variables = {
      TARGET_STREAM_NAME = aws_kinesis_stream.telemetry_ingest_stream.name
    }
  }
}

# 5. Connect the Event-Driven Monitor Directly to Invoke the Lambda Target Group
resource "aws_cloudwatch_event_rule" "scaler_trigger_rule" {
  name        = "capture-kinesis-iterator-failures"
  description = "Intercepts CloudWatch metric alarms indicating stream processing bottlenecks"

  event_pattern = jsonencode({
    "source": ["aws.cloudwatch"],
    "detail-type": ["CloudWatch Alarm State Change"],
    "detail": {
      "alarmName": [aws_cloudwatch_metric_alarm.iterator_age_alarm.name],
      "state": {
        "value": ["ALARM"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "bind_scaler_target" {
  rule      = aws_cloudwatch_event_rule.scaler_trigger_rule.name
  target_id = "InvokeStreamAutoScaler"
  arn       = aws_lambda_function.stream_autoscaler_worker.arn
}

# Allow EventBridge to Invoke the Lambda Function Natively
resource "aws_lambda_permission" "allow_eventbridge_scaler" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stream_autoscaler_worker.function_name
  principal     = "://amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scaler_trigger_rule.arn
}
