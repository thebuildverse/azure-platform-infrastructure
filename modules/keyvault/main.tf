terraform {
  required_providers {
    time = {
      source  = "hashicorp/time"
      version = ">= 0.12"
    }
  }
}

data "azurerm_client_config" "current" {}

resource "random_string" "kv_suffix" {
  length  = 8
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_key_vault" "main" {
  # Key Vault names must be globally unique, 3-24 chars, alphanumeric and hyphens
  name                = "kv-${substr(replace(var.name_prefix, "-", ""), 0, 10)}${random_string.kv_suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = var.tags

  sku_name                        = "standard"
  soft_delete_retention_days      = 7
  purge_protection_enabled        = false # Set true for production
  rbac_authorization_enabled      = true  # Use RBAC instead of access policies
  enabled_for_disk_encryption     = true
  enabled_for_deployment          = false
  enabled_for_template_deployment = false

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow" # Restrict in production
  }
}

# Grant the Terraform service principal admin access
resource "azurerm_role_assignment" "terraform_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "time_sleep" "wait_for_rbac" {
  depends_on      = [azurerm_role_assignment.terraform_admin]
  create_duration = "30s"
}

// this shouldnt be the case, remove this later, we don't need the terraform identity to be able to view key vault secrets anymore.