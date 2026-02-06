# =============================================================================
# CLUSTER ACCESS
# =============================================================================

output "kube_config" {
  description = "Kubernetes configuration for kubectl"
  value = {
    host                   = module.aks.cluster_host
    cluster_ca_certificate = module.aks.cluster_ca_certificate
  }
  sensitive = true
}

output "kube_config_command" {
  description = "Azure CLI command to get kubectl credentials"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.platform.name} --name ${module.aks.cluster_name} --admin"
}

# =============================================================================
# RESOURCE IDENTIFIERS
# =============================================================================

output "resource_group_platform" {
  description = "Platform resource group name"
  value       = azurerm_resource_group.platform.name
}

output "resource_group_shared" {
  description = "Shared resource group name"
  value       = azurerm_resource_group.shared.name
}

output "aks_cluster_id" {
  description = "AKS cluster resource ID"
  value       = module.aks.cluster_id
}

output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = module.aks.cluster_name
}

# =============================================================================
# CONTAINER REGISTRY
# =============================================================================

output "acr_login_server" {
  description = "ACR login server URL"
  value       = module.acr.login_server
}

output "acr_name" {
  description = "ACR name"
  value       = module.acr.name
}

output "acr_push_command" {
  description = "Example command to push an image to ACR"
  value       = "az acr login --name ${module.acr.name} && docker push ${module.acr.login_server}/myimage:tag"
}

# =============================================================================
# KEY VAULT
# =============================================================================

output "keyvault_name" {
  description = "Key Vault name for storing secrets"
  value       = module.keyvault.name
}

output "keyvault_uri" {
  description = "Key Vault URI"
  value       = module.keyvault.vault_uri
}

# =============================================================================
# MONITORING
# =============================================================================

output "grafana_url" {
  description = "Azure Managed Grafana URL"
  value       = module.monitoring.grafana_endpoint
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for queries"
  value       = azurerm_log_analytics_workspace.main.id
}

# =============================================================================
# ENDPOINTS
# =============================================================================

output "argocd_url" {
  description = "ArgoCD UI URL"
  value       = "https://argocd.${local.dns.zone_name}"
}

output "ingress_domain" {
  description = "Base domain for ingress resources"
  value       = local.dns.zone_name
}

# =============================================================================
# AZURE AD GROUPS
# =============================================================================

output "keyvault_admins_group" {
  description = "Azure AD group for Key Vault administrators"
  value       = module.azuread_groups.keyvault_admins_group_name
}

output "keyvault_readers_group" {
  description = "Azure AD group for Key Vault readers"
  value       = module.azuread_groups.keyvault_readers_group_name
}

output "monitoring_admins_group" {
  description = "Azure AD group for monitoring administrators"
  value       = module.azuread_groups.monitoring_admins_group_name
}

output "monitoring_readers_group" {
  description = "Azure AD group for monitoring viewers"
  value       = module.azuread_groups.monitoring_readers_group_name
}

output "aks_admins_group" {
  description = "Azure AD group for AKS cluster administrators"
  value       = "aks-admins-${local.name_prefix}"
}

output "aks_writers_group" {
  description = "Azure AD group for AKS cluster writers"
  value       = "aks-writers-${local.name_prefix}"
}

output "aks_readers_group" {
  description = "Azure AD group for AKS cluster readers"
  value       = "aks-readers-${local.name_prefix}"
}
