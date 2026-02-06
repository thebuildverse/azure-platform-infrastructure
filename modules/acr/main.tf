resource "random_string" "acr_suffix" {
  length  = 8
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_container_registry" "main" {
  # ACR names must be globally unique and alphanumeric only
  name                = "${replace(var.name_prefix, "-", "")}${random_string.acr_suffix.result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = var.admin_enabled
  tags                = var.tags

  # Prevent public network access in production
  # public_network_access_enabled = var.sku == "Premium" ? false : true

  dynamic "georeplications" {
    for_each = var.sku == "Premium" ? var.geo_replications : []
    content {
      location                = georeplications.value.location
      zone_redundancy_enabled = georeplications.value.zone_redundancy_enabled
      tags                    = var.tags
    }
  }
}

# Grant AKS kubelet identity pull access
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = var.aks_kubelet_identity_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.main.id
  skip_service_principal_aad_check = true
}
