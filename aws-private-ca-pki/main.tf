# =====================================================================
# CERTIFICATION SCENARIO 75: PRIVATE KEY INFRASTRUCTURE AUTOMATION
# COMPONENT: AWS PRIVATE CA DRIVING HANDS-FREE AUTOMATED TLS RENEWALS
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

# 1. Provision the Enterprise Root Private Certificate Authority (Root CA)
resource "aws_acmpca_certificate_authority" "root_ca" {
  type = "ROOT"

  # CRYPTOGRAPHIC IDENTITY PROFILE: Establishes your private corporate PKI root data
  certificate_authority_configuration {
    key_algorithm     = "RSA_4096" # Mandates ironclad asymmetric encryption bit-lengths
    signing_algorithm = "SHA512WITHRSA"

    subject {
      common_name         = "EliteDevOps Enterprise Root CA"
      organization        = "EliteDevOps Global Data Center"
      organizational_unit = "Security Operations Center"
      country             = "US"
      state               = "Virginia"
      locality            = "McLean"
    }
  }

  permanent_deletion_time_in_days = 7

  tags = {
    Layer      = "Global-Cryptographic-Identity"
    SavedAsset = "True"
  }
}

# 2. Issue and Self-Sign the Root Certificate Authority Identity
resource "aws_acmpca_certificate" "root_ca_cert" {
  certificate_authority_arn   = aws_acmpca_certificate_authority.root_ca.arn
  certificate_signing_request = aws_acmpca_certificate_authority.root_ca.certificate_signing_request
  signing_algorithm           = "SHA512WITHRSA"

  template_arn = "arn:aws:acm-pca:::template/RootCACertificate/V1"

  validity {
    type  = "YEARS"
    value = 10 # Establish a secure 10-year expiration horizon for the master root identity
  }
}

# 3. Securely Activate the Root CA Device on the Cloud Infrastructure Plane
resource "aws_acmpca_certificate_authority_certificate_activation" "activate_root" {
  certificate_authority_arn = aws_acmpca_certificate_authority.root_ca.arn
  certificate               = aws_acmpca_certificate.root_ca_cert.certificate
  certificate_chain         = aws_acmpca_certificate.root_ca_cert.certificate_chain
}

# 4. EXAM-SPECIFIC DESIGN PATTERN: Automated ACM Private Sub-Certificate Deployment
# This block uses our newly deployed private CA to issue a localized wild-card certificate.
# ACM intercept and manages this token, providing hands-free 365-day automated key rotation.
resource "aws_acm_certificate" "internal_microservice_tls" {
  domain_name       = "*.microservices.local" # Secures your entire Scenario 55 private discovery mesh!
  validation_method = "NONE"                  # Private CA certificates require zero external public DNS validation challenges

  # BINDING TUNNEL: Directs ACM to forge the key using your internal hardware root
  certificate_authority_arn = aws_acmpca_certificate_authority.root_ca.arn

  tags = {
    Compliance = "mTLS-Transit-Enforced"
  }

  depends_on = [aws_acmpca_certificate_authority_certificate_activation.activate_root]
}
