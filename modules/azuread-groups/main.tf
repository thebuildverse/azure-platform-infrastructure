# =============================================================================
# AZURE AD GROUPS MODULE
# =============================================================================
# This module creates Azure AD groups for managing access to Azure resources
# outside of AKS cluster access (which is handled in the AKS module).
#
# Groups created:
# - Key Vault Admins: Full management access to Key Vault secrets
# - Key Vault Readers: Read-only access to Key Vault secrets
# - Monitoring Admins: Full access to Grafana and monitoring resources
# - Monitoring Readers: Read-only access to Grafana and monitoring resources
# =============================================================================

# =============================================================================
# KEY VAULT GROUPS
# =============================================================================

# Key Vault Admins - Can create, update, delete secrets
# Use case: DevOps engineers, platform team members who manage secrets
resource "azuread_group" "keyvault_admins" {
  display_name     = "keyvault-admins-${var.name_prefix}"
  description      = "Members can manage secrets in Key Vault (create, update, delete)"
  security_enabled = true
}

# Key Vault Readers - Can only read secrets
# Use case: Applications, developers who need to view (not modify) secrets
resource "azuread_group" "keyvault_readers" {
  display_name     = "keyvault-readers-${var.name_prefix}"
  description      = "Members can read secrets from Key Vault"
  security_enabled = true
}

# =============================================================================
# MONITORING GROUPS
# =============================================================================

# Monitoring Admins - Full access to Grafana dashboards and monitoring config
# Use case: SRE team, platform engineers who configure monitoring
resource "azuread_group" "monitoring_admins" {
  display_name     = "monitoring-admins-${var.name_prefix}"
  description      = "Members have full admin access to Grafana and monitoring resources"
  security_enabled = true
}

# Monitoring Readers - View-only access to Grafana dashboards
# Use case: Developers, stakeholders who need to view metrics
resource "azuread_group" "monitoring_readers" {
  display_name     = "monitoring-readers-${var.name_prefix}"
  description      = "Members can view Grafana dashboards and monitoring data"
  security_enabled = true
}

# =============================================================================
# KEY VAULT ROLE ASSIGNMENTS
# =============================================================================

# Grant Key Vault Admins full secrets management
resource "azurerm_role_assignment" "keyvault_admin" {
  scope                = var.keyvault_id
  role_definition_name = "Key Vault Administrator"
  principal_id         = azuread_group.keyvault_admins.object_id
}

# Grant Key Vault Readers secrets read access
resource "azurerm_role_assignment" "keyvault_reader" {
  scope                = var.keyvault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azuread_group.keyvault_readers.object_id
}

# =============================================================================
# MONITORING ROLE ASSIGNMENTS
# =============================================================================

# Grant Monitoring Admins Grafana Admin role
resource "azurerm_role_assignment" "grafana_admin" {
  scope                = var.grafana_id
  role_definition_name = "Grafana Admin"
  principal_id         = azuread_group.monitoring_admins.object_id
}

# Grant Monitoring Admins Monitoring Contributor on Azure Monitor workspace
resource "azurerm_role_assignment" "monitoring_admin_contributor" {
  scope                = var.monitor_workspace_id
  role_definition_name = "Monitoring Contributor"
  principal_id         = azuread_group.monitoring_admins.object_id
}

# Grant Monitoring Readers Grafana Viewer role
resource "azurerm_role_assignment" "grafana_viewer" {
  scope                = var.grafana_id
  role_definition_name = "Grafana Viewer"
  principal_id         = azuread_group.monitoring_readers.object_id
}

# Grant Monitoring Readers read access to monitoring data
resource "azurerm_role_assignment" "monitoring_reader" {
  scope                = var.monitor_workspace_id
  role_definition_name = "Monitoring Reader"
  principal_id         = azuread_group.monitoring_readers.object_id
}
