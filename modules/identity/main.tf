# =============================================================================
# EXTERNAL DNS IDENTITY
# =============================================================================

resource "azurerm_user_assigned_identity" "external_dns" {
  name                = "id-${var.name_prefix}-external-dns"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "external_dns" {
  name                = "fic-external-dns"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.external_dns.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  subject             = "system:serviceaccount:external-dns:external-dns"
}

# DNS Zone Contributor - allows managing DNS records
resource "azurerm_role_assignment" "external_dns_zone_contributor" {
  scope                = var.dns_zone_id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.external_dns.principal_id
}

# Reader on DNS resource group - required for listing zones
data "azurerm_resource_group" "dns" {
  name = var.dns_zone_resource_group
}

resource "azurerm_role_assignment" "external_dns_rg_reader" {
  scope                = data.azurerm_resource_group.dns.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.external_dns.principal_id
}

# =============================================================================
# EXTERNAL SECRETS IDENTITY
# =============================================================================

resource "azurerm_user_assigned_identity" "external_secrets" {
  name                = "id-${var.name_prefix}-external-secrets"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "external_secrets" {
  name                = "fic-external-secrets"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.external_secrets.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  subject             = "system:serviceaccount:external-secrets:external-secrets"
}

# Key Vault Secrets User - allows reading secrets
resource "azurerm_role_assignment" "external_secrets_kv_reader" {
  scope                = var.keyvault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.external_secrets.principal_id
}
