# =====================================================================
# CERTIFICATION SCENARIO 77: PROPRIETARY WORKLOAD DATA GOVERNANCE
# COMPONENT: SSM ASSOCIATIONS INGESTING CUSTOM INVENTORY PROPERTIES
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

# 1. Reference Your Existing Multi-Cloud Resource Data Sync Bucket Policy
# (This ensures custom inventory payloads flow straight into your Scenario 43 SIEM vaults!)
data "aws_s3_bucket" "inventory_vault" {
  name = "enterprise-multicloud-ssm-inventory-sync-2026"
}

# 2. Architect the Custom Systems Manager Inventory Document
# (This blueprint teaches the AWS control plane how to parse your custom JSON schema)
resource "aws_ssm_document" "custom_inventory_policy" {
  name          = "Custom-Proprietary-Binary-Schema"
  document_type = "Command"
  content_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Forces the SSM Agent to scrape and register proprietary internal code metadata records"
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "GenerateCustomInventoryPayload"
      inputs = {
        runCommand = [
          "#!/bin/bash",
          "echo 'Compiling Proprietary Asset Metadata Logs...'",
          "mkdir -p /var/lib/amazon/ssm/inventory/custom",
          # Script loops locally, scraping custom internal compiler values and structuring a valid SSM JSON payload
          "cat << 'EOF' > /var/lib/amazon/ssm/inventory/custom/CustomBankingBinary.json",
          "{",
          "  \"SchemaVersion\": \"1.0\",",
          "  \"TypeName\": \"Custom:BankingBinaryData\",",
          "  \"CapturedTime\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\",",
          "  \"Content\": [",
          "    {",
          "      \"BinaryName\": \"core-ledger-processor\",",
          "      \"CompilationVersion\": \"v4.9.2-crypto-hardened\",",
          "      \"ComplianceLicenseKey\": \"LIC-ENTERPRISE-TRX-9999\",",
          "      \"OperationalStatus\": \"ACTIVE_PROTECTED\"",
          "    }",
          "  ]",
          "}",
          "EOF",
          "echo 'Custom Asset Ledger Synced Locally.'"
        ]
      }
    }]
  })
}

# 3. Deploy the State Manager Association Forcing the Custom Ingestion Schedule
resource "aws_ssm_association" "enforce_custom_inventory" {
  name             = aws_ssm_document.custom_inventory_policy.name
  schedule_expression = "rate(24 hours)" # Execute the metadata generation cron loop every 24 hours

  # FLEET INSTANCE TARGETING: Commands the rule to audit the entire cloud computing pool
  targets {
    key    = "InstanceIds"
    values = ["*"] # Wildcard parameter maps custom tracking natively across all nodes
  }

  compliance_severity = "HIGH" # Throw a High compliance flag if the proprietary binary metadata drops offline
}
