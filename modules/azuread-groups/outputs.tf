# =============================================================================
# KEY VAULT GROUP OUTPUTS
# =============================================================================

output "keyvault_admins_group_id" {
  description = "Object ID of the Key Vault Admins Azure AD group"
  value       = azuread_group.keyvault_admins.object_id
}

output "keyvault_admins_group_name" {
  description = "Display name of the Key Vault Admins Azure AD group"
  value       = azuread_group.keyvault_admins.display_name
}

output "keyvault_readers_group_id" {
  description = "Object ID of the Key Vault Readers Azure AD group"
  value       = azuread_group.keyvault_readers.object_id
}

output "keyvault_readers_group_name" {
  description = "Display name of the Key Vault Readers Azure AD group"
  value       = azuread_group.keyvault_readers.display_name
}

# =============================================================================
# MONITORING GROUP OUTPUTS
# =============================================================================

output "monitoring_admins_group_id" {
  description = "Object ID of the Monitoring Admins Azure AD group"
  value       = azuread_group.monitoring_admins.object_id
}

output "monitoring_admins_group_name" {
  description = "Display name of the Monitoring Admins Azure AD group"
  value       = azuread_group.monitoring_admins.display_name
}

output "monitoring_readers_group_id" {
  description = "Object ID of the Monitoring Readers Azure AD group"
  value       = azuread_group.monitoring_readers.object_id
}

output "monitoring_readers_group_name" {
  description = "Display name of the Monitoring Readers Azure AD group"
  value       = azuread_group.monitoring_readers.display_name
}
