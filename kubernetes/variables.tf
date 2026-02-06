variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "domain_name" {
  description = "Domain name for ingress resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
}

variable "dns_zone_resource_group" {
  description = "DNS zone resource group name"
  type        = string
}

variable "keyvault_uri" {
  description = "Key Vault URI"
  type        = string
}

variable "acr_login_server" {
  description = "ACR login server URL"
  type        = string
}

variable "external_dns_identity_client_id" {
  description = "External DNS managed identity client ID"
  type        = string
}

variable "external_secrets_identity_client_id" {
  description = "External Secrets managed identity client ID"
  type        = string
}

variable "cert_manager_email" {
  description = "Email for Let's Encrypt certificate notifications"
  type        = string
}

variable "helm_versions" {
  description = "Helm chart versions"
  type = object({
    ingress_nginx    = string
    cert_manager     = string
    external_dns     = string
    external_secrets = string
    argocd           = string
    kyverno          = string
  })
}

variable "argocd_github_org" {
  description = "GitHub organization for ArgoCD SSO"
  type        = string
}

variable "argocd_admin_users" {
  description = "GitHub usernames with ArgoCD admin access"
  type        = list(string)
}

variable "argocd_github_client_id" {
  description = "GitHub OAuth Client ID for ArgoCD"
  type        = string
}

variable "argocd_github_client_secret" {
  description = "GitHub OAuth Client Secret for ArgoCD"
  type        = string
  sensitive   = true
}

# =============================================================================
# KYVERNO CONFIGURATION
# =============================================================================

variable "enable_kyverno" {
  description = "Enable Kyverno policy engine deployment"
  type        = bool
  default     = true
}

variable "enable_kyverno_policies" {
  description = "Enable Kyverno policies (requires enable_kyverno = true)"
  type        = bool
  default     = true
}

variable "enable_registry_restriction" {
  description = "Enable image registry restriction policy"
  type        = bool
  default     = false
}

variable "allowed_registries" {
  description = "List of allowed container registries (used when enable_registry_restriction = true)"
  type        = list(string)
  default = [
    "*.azurecr.io/",         # Azure Container Registry
    "registry.k8s.io/",       # Kubernetes official images
    "docker.io/",             # Docker Hub
    "ghcr.io/",               # GitHub Container Registry
    "quay.io/",               # Red Hat Quay
    "mcr.microsoft.com/"      # Microsoft Container Registry
  ]
}

# =============================================================================
# CILIUM CONFIGURATION
# =============================================================================

variable "enable_cilium_policies" {
  description = "Enable Cilium network policies for zero-trust networking"
  type        = bool
  default     = true
}
