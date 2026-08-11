# =====================================================================
# CERTIFICATION SCENARIO 52: SERVERLESS DISTRIBUTED OBSERVABILITY
# COMPONENT: AWS X-RAY TRACING AND CLOUDWATCH EMBEDDED METRIC FORMATS
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

# 1. Create a Secure IAM Execution Role for the Observability Function
resource "aws_iam_role" "lambda_telemetry_role" {
  name = "DataCenter-Lambda-XRay-Telemetry-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

# Bind explicit X-Ray tracing write and CloudWatch logging privileges
resource "aws_iam_role_policy_attachment" "xray_write_access" {
  role       = aws_iam_role.lambda_telemetry_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess" # Native AWS managed tracing token
}

resource "aws_iam_role_policy_attachment" "cloudwatch_write_access" {
  role       = aws_iam_role.lambda_telemetry_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# 2. Architect the Hardened Lambda Function with Active Tracing Enabled
resource "aws_lambda_function" "telemetry_processor" {
  function_name = "Enterprise-Core-Serverless-TelemetryProcessor"
  role          = aws_iam_role.lambda_telemetry_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "mock-telemetry-payload.zip"

  # OBSERVABILITY CONTROL: Instantly arms active distributed transaction tracing
  tracing_config {
    mode = "Active"
  }

  # Injected environmental instruction command enabling CloudWatch EMF formatting rules
  environment {
    variables = {
      AWS_EMF_NAMESPACE = "DataCenter/CustomMicroserviceMetrics"
    }
  }

  tags = {
    Layer      = "Serverless-Observability-Tier"
    SavedAsset = "True"
  }
}

# 3. Configure the Global X-Ray Sampling Rule (Defines traffic tracking volume)
resource "aws_xray_sampling_rule" "custom_sampling" {
  rule_name      = "enterprise-microservice-sampling-rules"
  priority       = 1000
  version        = 1
  reservoir_size = 1   # Force at least 1 transaction request trace per second to establish a baseline
  fixed_rate     = 0.05 # Sample exactly 5% of remaining concurrent traffic payloads dynamically
  
  host           = "*"
  http_method    = "*"
  url_path       = "*"
  service_name   = aws_lambda_function.telemetry_processor.function_name
  service_type   = "*"

  attributes = {
    "Environment" = "production"
  }
}
