# Azure Service Principal Credentials
# These should be configured as environment variables in Terraform Cloud:
# - ARM_CLIENT_ID
# - ARM_CLIENT_SECRET (sensitive)
# - ARM_TENANT_ID
# - ARM_SUBSCRIPTION_ID
# - argocd_github_client_id
# - argocd_github_client_secret

variable "arm_client_id" {
  description = "Azure Service Principal Application (client) ID"
  type        = string
}

variable "arm_client_secret" {
  description = "Azure Service Principal client secret"
  type        = string
  sensitive   = true
}

variable "arm_tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

variable "arm_subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "argocd_github_client_id" {
  description = "GitHub OAuth App Client ID for ArgoCD SSO"
  type        = string
}

variable "argocd_github_client_secret" {
  description = "GitHub OAuth App Client Secret for ArgoCD SSO"
  type        = string
  sensitive   = true
}