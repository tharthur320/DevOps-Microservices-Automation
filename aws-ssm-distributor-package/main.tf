# =====================================================================
# CERTIFICATION SCENARIO 70: FLEET-WIDE SOFTWARE WORKLOAD AUTOMATION
# COMPONENT: SSM DISTRIBUTOR MANIFESTS DRIVING COMPLIANCE ENFORCEMENT
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

# 1. Reference Your Central Secure S3 Storage Bucket (Where agent binaries live)
data "aws_s3_bucket" "binaries_vault" {
  name = "enterprise-immutable-regulatory-ledgers-2026" # Reuses your Phase 5 encrypted vault asset!
}

# 2. Architect the Centralized AWS Systems Manager (SSM) Distributor Package
resource "aws_ssm_document" "security_agent_package" {
  name          = "Enterprise-HostSecurity-Agent"
  document_type = "Package" # Mandates the Distributor distribution engine format
  content_format = "JSON"

  # DISTRIBUTOR MANIFEST: Programs multi-platform target paths and hash validations
  content = jsonencode({
    schemaVersion = "2.0"
    version       = "1.0.0"
    publisher     = "EliteDevOps Security Operations"
    packages = {
      amazon = {
        _any = {
          x86_64 = {
            file = "security-agent-linux.rpm"
          }
        }
      },
      windows = {
        _any = {
          x86_64 = {
            file = "security-agent-windows.msi"
          }
        }
      }
    }
    files = {
      "security-agent-linux.rpm" = {
        checksums = {
          sha256 = "64cryptographiccharacterstringhashformockvalidationtesting0000"
        }
        downloadLocation = "https://${data.aws_s3_bucket.binaries_vault.id}://"
      },
      "security-agent-windows.msi" = {
        checksums = {
          sha256 = "64cryptographiccharacterstringhashformockvalidationtesting1111"
        }
        downloadLocation = "https://${data.aws_s3_bucket.binaries_vault.id}://"
      }
    }
  })
}

# 3. Deploy the Fleet-Wide State Manager Association (The Installation Enforcer)
resource "aws_ssm_association" "enforce_agent_installation" {
  name             = "AWS-ConfigureAWSPackage" # Built-in native AWS installation and configuration utility
  schedule_expression = "rate(1 day)"            # Re-verify and enforce package installations every 24 hours

  # FLEET INSTANCE TARGETING: Commands the rule to scan all active data center servers
  targets {
    key    = "InstanceIds"
    values = ["*"] # Wildcard parameter applies this rule globally across the multi-cloud nodes
  }

  compliance_severity = "CRITICAL" # Escalate status to Critical if an agent is uninstalled or tampered with

  # PARAMETERS INJECTION: Instructs the SSM engine to execute an active Install lifecycle action
  parameters = {
    action  = "Install"
    name    = aws_ssm_document.security_agent_package.name
    version = "1.0.0"
  }
}
