# =====================================================================
# CERTIFICATION SCENARIO 19: MULTI-ACCOUNT FIREWALL SECURITY GOVERNANCE
# COMPONENT: AWS FIREWALL MANAGER FOR ENFORCING GLOBAL PERIMETER SHIEILDS
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Provision the Hardened Central Corporate WAFv2 Web ACL Ruleset Baseline
# (This represents the master threat shield rule template copied to all accounts)
resource "aws_wafv2_web_acl" "master_security_shield" {
  name        = "enterprise-global-perimeter-shield"
  description = "Master corporate Web ACL intercepting Layer-7 vulnerabilities"
  scope       = "REGIONAL"

  default_action {
    allow {} # Default posture allowing standard traffic through to the verification rules
  }

  # OWASP Core Rule Set: Automatically blocks common web exploits like SQLi and XSS
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_set_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "MasterPerimeterShieldMetric"
    sampled_requests_enabled   = true
  }
}

# 2. Architect the Enterprise AWS Firewall Manager (FMS) Global Enforcement Policy
resource "aws_fms_policy" "global_waf_enforcer" {
  name                  = "enterprise-automatic-waf-enforcement"
  exclude_resource_tags = false
  remediation_enabled   = true # ENFORCES AUTOMATIC REMEDIATION & INJECTION ACROSS ALL ACCOUNTS
  resource_type_list    = ["AWS::ElasticLoadBalancingV2::LoadBalancer"] # Targets ALBs globally

  # Security Service Data: Injects your master WAF ACL straight into the FMS policy block
  security_service_policy_data {
    type = "WAFV2"
    managed_service_data = jsonencode({
      type = "WAFV2"
      webACLId = aws_wafv2_web_acl.master_security_shield.id
      overrideAction = { type = "NONE" }
    })
  }

  # Organizational Scope: Commands the rule to apply across all connected corporate sub-accounts
  include_map {
    account = ["*"] # Denotes an all-inclusive wildcard organizational account mapping
  }

  tags = {
    Layer      = "Global-Perimeter-Governance"
    SavedAsset = "True"
  }
}
