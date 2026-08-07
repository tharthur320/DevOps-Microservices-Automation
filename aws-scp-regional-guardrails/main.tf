# =====================================================================
# CERTIFICATION SCENARIO 26: ORGANIZATIONAL COMPLIANCE GOVERNANCE
# COMPONENT: SERVICE CONTROL POLICIES (SCPS) ENFORCING GEOGRAPHIC LOCKS
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Architect the Enterprise Regional Enforcement Service Control Policy (SCP)
# (This master rule is deployed exclusively inside your Organization Root account)
resource "aws_organizations_policy" "regional_guardrail" {
  name        = "enterprise-strict-regional-boundary-policy"
  description = "Ironclad organizational guardrail blocking resource creation outside approved US regions"
  type        = "SERVICE_CONTROL_POLICY"

  # JSON Policy Document: Universal Deny structure with explicit string-matching exceptions
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyAllOutsideApprovedRegions"
        Effect = "Deny"
        
        # Wildcard Actions block forces this rule to apply to ALL cloud operations globally
        Action = "*"
        Resource = "*"
        
        Condition = {
          StringNotEquals = {
            # EXPLICIT BYPASS: Whitelist only your core operational and fallback datacenters
            "aws:RequestedRegion" = [
              "us-east-1", # Primary Hub (Virginia)
              "us-west-2"  # Backup Hub (Oregon)
            ]
          }
          # Structural Safeguard: Prevent this policy from breaking universal global cloud operations
          "ForAnyValue:StringNotEquals" = {
            "aws:CalledVia" = [
              "://amazonaws.com",
              "://amazonaws.com",
              "://amazonaws.com",
              "://amazonaws.com"
            ]
          }
        }
      }
    ]
  })
}

# 2. Bind the Guardrail Policy Securely to an Organizational Unit (OU)
# (This enforces the policy down onto all child sub-accounts sitting inside that folder)
resource "aws_organizations_policy_attachment" "ou_enforcement_binding" {
  policy_id = aws_organizations_policy.regional_guardrail.id
  target_id = "ou-1111-22222222" # Replaced with your specific Target Production OU ID strings
}
