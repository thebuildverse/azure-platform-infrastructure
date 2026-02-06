output "id" {
  description = "ACR resource ID"
  value       = azurerm_container_registry.main.id
}

output "name" {
  description = "ACR name"
  value       = azurerm_container_registry.main.name
}

output "login_server" {
  description = "ACR login server URL"
  value       = azurerm_container_registry.main.login_server
}

output "admin_username" {
  description = "ACR admin username (if enabled)"
  value       = var.admin_enabled ? azurerm_container_registry.main.admin_username : null
  sensitive   = true
}

output "admin_password" {
  description = "ACR admin password (if enabled)"
  value       = var.admin_enabled ? azurerm_container_registry.main.admin_password : null
  sensitive   = true
}
