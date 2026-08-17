# =====================================================================
# CERTIFICATION SCENARIO 152: ZERO-TRUST IDENTITY FEDERATION
# COMPONENT: IAM SAML PROVIDERS MAPPING COMPACT CORPORATE IDP ACCESS
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

# 1. Provision the Enterprise Corporate SAML Identity Provider Trust Anchor
resource "aws_iam_saml_provider" "corporate_idp" {
  name                   = "enterprise-corporate-okta-idp"
  saml_metadata_document = <<EOF
<?xml version="1.0" encoding="UTF-8"?>

  <md:IDPSSODescriptor WantAuthnRequestsSigned="true" protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
    <md:KeyDescriptor use="signing">
      <ds:KeyInfo xmlns:ds="http://w3.org">
        <ds:X509Data>
          <ds:X509Certificate>MIIETjCCAzagAwIBAgIRAI...MOCK-IDP-CERTIFICATE-DATA...</ds:X509Certificate>
        </ds:X509Data>
      </ds:KeyInfo>
    </md:KeyDescriptor>
    <md:SingleSignOnService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" Location="https://enterprise.corp"/>
  </md:IDPSSODescriptor>
</md:EntityDescriptor>
EOF
}

# 2. Architect the Hardened Federated Assume-Role Bridge for Cloud Architects
resource "aws_iam_role" "federated_architect_role" {
  name        = "Enterprise-Federated-CloudArchitect"
  description = "Role assumed dynamically by corporate directory users mapped to Cloud Architect tracks"

  # ENFORCES STRICT FEDERATED TRUST CORRIDORS
  # Only permits access requests arriving through the verified SAML provider token channels
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowSAMLFederationToAssumeRole"
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_saml_provider.corporate_idp.arn
      }
      Action = "sts:AssumeRoleWithSAML"
      Condition = {
        StringEquals = {
          "SAML:aud" = "https://amazon.com" # Enforces standard native console ingress routing
        }
      }
    }]
  })

  tags = {
    Layer      = "Identity-Federation-Core"
    SavedAsset = "True"
  }
}

# 3. Attach Restrictive Operational Privileges onto the Federated Identity Bridge
resource "aws_iam_role_policy_attachment" "architect_read_only" {
  role       = aws_iam_role.federated_architect_role.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess" # Baseline reading privileges delegated to federated users
}
