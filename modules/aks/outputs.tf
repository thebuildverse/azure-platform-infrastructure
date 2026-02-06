output "cluster_id" {
  description = "AKS cluster resource ID"
  value       = azurerm_kubernetes_cluster.main.id
}

output "cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.main.name
}

output "cluster_fqdn" {
  description = "AKS cluster FQDN"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "cluster_host" {
  description = "Kubernetes API server endpoint"
  value       = azurerm_kubernetes_cluster.main.kube_admin_config[0].host
  sensitive   = true
}

output "cluster_client_certificate" {
  description = "Base64 encoded client certificate"
  value       = azurerm_kubernetes_cluster.main.kube_admin_config[0].client_certificate
  sensitive   = true
}

output "cluster_client_key" {
  description = "Base64 encoded client key"
  value       = azurerm_kubernetes_cluster.main.kube_admin_config[0].client_key
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64 encoded cluster CA certificate"
  value       = azurerm_kubernetes_cluster.main.kube_admin_config[0].cluster_ca_certificate
  sensitive   = true
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity"
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "kubelet_identity_object_id" {
  description = "Kubelet managed identity object ID"
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

output "kubelet_identity_client_id" {
  description = "Kubelet managed identity client ID"
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].client_id
}

output "admin_group_id" {
  description = "AKS admin Azure AD group ID"
  value       = azuread_group.cluster_admins.object_id
}

output "writer_group_id" {
  description = "AKS writer Azure AD group ID"
  value       = azuread_group.cluster_writers.object_id
}

output "reader_group_id" {
  description = "AKS reader Azure AD group ID"
  value       = azuread_group.cluster_readers.object_id
}
