# =====================================================================
# CERTIFICATION SCENARIO 16: GLOBAL IDENTITY SECURITY GOVERNANCE
# COMPONENT: EVENTBRIDGE & LAMBDA CAPTURING ROGUE IDENTITY TAMPERING
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Architect the EventBridge Rule Intercepting Global IAM Role API Events
resource "aws_cloudwatch_event_rule" "iam_governance_rule" {
  name        = "audit-global-iam-role-modifications"
  description = "Triggers the security gatekeeper if an IAM role is generated or edited"

  # Event Pattern: Intercepts native AWS IAM structural write/update actions via CloudTrail
  event_pattern = jsonencode({
    "source": ["aws.iam"],
    "detail-type": ["AWS API Call via CloudTrail"],
    "detail": {
      "eventName": [
        "CreateRole",
        "UpdateRole",
        "UpdateRoleDescription",
        "UpdateAssumeRolePolicy"
      ]
    }
  })
}

# 2. Architect the Serverless Identity Auditor Function (AWS Lambda)
resource "aws_lambda_function" "iam_security_auditor" {
  function_name = "Enterprise-Core-IAM-IdentityAuditor"
  role          = aws_iam_role.auditor_exec_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"

  # Inline security boundary policy granting Lambda capabilities to read and restrict IAM metadata
  inline_policy {
    name = "LambdaIAMAuditPrivileges"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "iam:GetRole",
            "iam:UpdateAssumeRolePolicy"
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

  # Environment Variables loading your trusted internal company AWS account whitelist
  environment {
    variables = {
      APPROVED_ACCOUNT_WHITELIST = "111111111111,222222222222" # Securely referenced from parameters in prod
    }
  }
}

# 3. Bind the Event-Driven Monitor Directly to the Lambda Security Target
resource "aws_cloudwatch_event_target" "bind_auditor_target" {
  rule      = aws_cloudwatch_event_rule.iam_governance_rule.name
  target_id = "InvokeIdentitySecurityAuditor"
  arn       = aws_lambda_function.iam_security_auditor.arn
}

# 4. Create the Secure IAM Execution Role for the Governance Compliance Engine
resource "aws_iam_role" "auditor_exec_role" {
  name = "DataCenter-IAM-Governance-Auditor-Runner"

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
resource "aws_lambda_permission" "allow_eventbridge_audit_execution" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.iam_security_auditor.function_name
  principal     = "://amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.iam_governance_rule.arn
}
