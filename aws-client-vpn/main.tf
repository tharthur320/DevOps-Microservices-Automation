# =====================================================================
# CERTIFICATION SCENARIO 39: ZERO-TRUST SECURE REMOTE ADMINISTRATION
# COMPONENT: AWS CLIENT VPN ENDPOINTS MAPPED TO MUTUAL TLS ACM CERTS
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Reference Your Private Data Center Network Infrastructure Core Boundaries
resource "aws_vpc" "vpn_vpc" {
  cidr_block           = "10.120.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "Secure-Admin-Network" }
}

resource "aws_subnet" "private_admin_subnet" {
  vpc_id            = aws_vpc.vpn_vpc.id
  cidr_block        = "10.120.10.0/24"
  availability_zone = "us-east-1a"
  tags                 = { Name = "Private-Admin-Hallway" }
}

# 2. Upload and Reference Cryptographic Mutual TLS Authentication Keys into ACM
# (In production, these are generated via local EasyRSA tools and passed as secure parameters)
resource "aws_acm_certificate" "server_cert" {
  domain_name       = "://elitedevopsenterprise.com"
  certificate_body  = "-----BEGIN CERTIFICATE-----\nMOCK...SERVER...CERT\n-----END CERTIFICATE-----"
  private_key       = "-----BEGIN PRIVATE KEY-----\nMOCK...SERVER...KEY\n-----END PRIVATE KEY-----"
  certificate_chain = "-----BEGIN CERTIFICATE-----\nMOCK...CA...CHAIN\n-----END CERTIFICATE-----"
}

resource "aws_acm_certificate" "client_cert" {
  domain_name       = "://elitedevopsenterprise.com"
  certificate_body  = "-----BEGIN CERTIFICATE-----\nMOCK...CLIENT...CERT\n-----END CERTIFICATE-----"
  certificate_chain = "-----BEGIN CERTIFICATE-----\nMOCK...CA...CHAIN\n-----END CERTIFICATE-----"
}

# 3. Architect the Hardened AWS Client VPN Endpoint Gate
resource "aws_ec2_client_vpn_endpoint" "admin_vpn" {
  description            = "Enterprise administration gateway enforcing mutual TLS encrypted tunnels"
  server_certificate_arn = aws_acm_certificate.server_cert.arn
  client_cidr_block      = "10.240.0.0/22" # Isolated network block allocated to incoming VPN client sessions
  split_tunnel           = true           # Route only corporate datacenter traffic over the secure tunnel

  # MUTUAL TLS ENFORCEMENT LAYER: Restricts access strictly to verified client keys
  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.client_cert.arn
  }

  connection_log_options {
    enabled               = true
    cloudwatch_log_group  = "enterprise-vpn-audit-logs"
    cloudwatch_log_stream = "connections"
  }

  tags = {
    Layer      = "Administrative-Access-Shield"
    SavedAsset = "True"
  }
}

# 4. Bind the Secure VPN Entryway Directly into Your Private Network Core Subnet
resource "aws_ec2_client_vpn_network_association" "subnet_association" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.admin_vpn.id
  subnet_id              = aws_subnet.private_admin_subnet.id
}

# 5. Authorize Inbound VPN Network Traffic to Flow Cleanly Across the Private Subnet
resource "aws_ec2_client_vpn_authorization_rule" "authorize_all_internal" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.admin_vpn.id
  target_network_cidr    = aws_vpc.vpn_vpc.cidr_block
  authorize_all_groups   = true
}
