# =====================================================================
# CERTIFICATION SCENARIO 12: SECURE SOFTWARE SUPPLY CHAIN MANAGEMENT
# COMPONENT: AWS CODEARTIFACT ENFORCING UPSTREAM DEPENDENCY ISOLATION
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Establish the Cryptographic Corporate Governance Domain Boundary
resource "aws_codeartifact_domain" "enterprise_domain" {
  domain = "enterprise-confidential-software-vault"
  
  # Encryption: Integrates a custom master key to lock down the dependency assets
  encryption_key = "arn:aws:kms:us-east-1:123456789012:key/mock-key-id" 

  tags = {
    Layer      = "SupplyChain-Security"
    SavedAsset = "True"
  }
}

# 2. Deploy the Upstream External Proxy Repository (Linked to Public Registries)
resource "aws_codeartifact_repository" "upstream_proxy_repo" {
  domain     = aws_codeartifact_domain.enterprise_domain.domain
  repository = "public-npm-proxy-gateway"
  
  # External Connection: Locks the repository to pull strictly from the official npm public vault
  external_connections {
    external_connection_name = "public:npmjs"
  }
}

# 3. Deploy the Isolated Private Corporate Code Repository (Where your developers work)
resource "aws_codeartifact_repository" "private_repo" {
  domain     = aws_codeartifact_domain.enterprise_domain.domain
  repository = "internal-proprietary-packages"

  # Upstream Dependency Chaining: Forces the private repo to route through the public proxy
  # if an open-source dependency is requested, maintaining a single audited path.
  upstream {
    repository_name = aws_codeartifact_repository.upstream_proxy_repo.repository
  }
}

# 4. Enforce Strict Resource Policies Restricting Access to Internal CI/CD Engines
resource "aws_codeartifact_repository_permissions_policy" "restrictive_access" {
  domain          = aws_codeartifact_domain.enterprise_domain.domain
  repository      = aws_codeartifact_repository.private_repo.repository
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowPipelineAccessOnly"
        Effect    = "Allow"
        Principal = {
          # Whitelists strictly your corporate build automation execution roles
          AWS = "arn:aws:iam::123456789012:role/Pipeline-Build-ExecutionRole" 
        }
        Action = [
          "codeartifact:GetRepositoryEndpoint",
          "codeartifact:ReadFromRepository"
        ]
        Resource = "*"
      }
    ]
  })
}
