output "external_dns_identity_id" {
  description = "External DNS managed identity resource ID"
  value       = azurerm_user_assigned_identity.external_dns.id
}

output "external_dns_identity_client_id" {
  description = "External DNS managed identity client ID"
  value       = azurerm_user_assigned_identity.external_dns.client_id
}

output "external_dns_identity_principal_id" {
  description = "External DNS managed identity principal ID"
  value       = azurerm_user_assigned_identity.external_dns.principal_id
}

output "external_secrets_identity_id" {
  description = "External Secrets managed identity resource ID"
  value       = azurerm_user_assigned_identity.external_secrets.id
}

output "external_secrets_identity_client_id" {
  description = "External Secrets managed identity client ID"
  value       = azurerm_user_assigned_identity.external_secrets.client_id
}

output "external_secrets_identity_principal_id" {
  description = "External Secrets managed identity principal ID"
  value       = azurerm_user_assigned_identity.external_secrets.principal_id
}
