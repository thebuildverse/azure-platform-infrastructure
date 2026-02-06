# =============================================================================
# RESOURCE GROUPS
# =============================================================================

resource "azurerm_resource_group" "platform" {
  name     = "rg-${local.name_prefix}"
  location = local.location
  tags     = local.tags
}

resource "azurerm_resource_group" "shared" {
  name     = "rg-shared-${local.location_short}"
  location = local.location
  tags     = local.tags
}

# =============================================================================
# DATA SOURCES
# =============================================================================

data "azurerm_subscription" "current" {}

data "azurerm_dns_zone" "main" {
  name                = local.dns.zone_name
  resource_group_name = local.dns.zone_resource_group
}

# =============================================================================
# LOG ANALYTICS (Created early - needed by AKS)
# =============================================================================

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${local.name_prefix}"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  sku                 = "PerGB2018"
  retention_in_days   = local.monitoring.log_retention_days
  tags                = local.tags
}

# =============================================================================
# NETWORKING
# =============================================================================

module "networking" {
  source = "./modules/networking"

  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  name_prefix         = local.name_prefix
  tags                = local.tags

  vnet_address_space = local.network.vnet_address_space
  subnets            = local.network.subnets
}

# =============================================================================
# KEY VAULT
# =============================================================================

module "keyvault" {
  source = "./modules/keyvault"

  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  name_prefix         = "shared-${local.location_short}"
  tags                = local.tags

}

# =============================================================================
# AKS CLUSTER
# =============================================================================

module "aks" {
  source = "./modules/aks"

  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  name_prefix         = local.name_prefix
  tags                = local.tags

  kubernetes_version = local.aks.kubernetes_version
  sku_tier           = local.aks.sku_tier
  default_node_pool  = local.aks.default_node_pool

  node_subnet_id = module.networking.node_subnet_id
  pod_subnet_id  = module.networking.pod_subnet_id

  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  depends_on = [module.networking]
}

# =============================================================================
# CONTAINER REGISTRY
# =============================================================================

module "acr" {
  source = "./modules/acr"

  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  name_prefix         = replace("shared${local.location_short}", "-", "")
  tags                = local.tags

  sku                     = local.acr.sku
  admin_enabled           = local.acr.admin_enabled
  aks_kubelet_identity_id = module.aks.kubelet_identity_object_id
}

# =============================================================================
# MONITORING
# =============================================================================

module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  name_prefix         = local.name_prefix
  tags                = local.tags

  aks_cluster_id             = module.aks.cluster_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  grafana_sku                = local.monitoring.grafana_sku
  grafana_major_version      = local.monitoring.grafana_major_version

  depends_on = [module.aks]
}

# =============================================================================
# AZURE AD GROUPS
# =============================================================================
# Creates Azure AD groups for managing access to Key Vault and Monitoring
# resources. These are separate from AKS cluster access groups (in AKS module).

module "azuread_groups" {
  source = "./modules/azuread-groups"

  name_prefix          = local.name_prefix
  keyvault_id          = module.keyvault.id
  grafana_id           = module.monitoring.grafana_id
  monitor_workspace_id = module.monitoring.monitor_workspace_id

  depends_on = [module.keyvault, module.monitoring]
}

# =============================================================================
# MANAGED IDENTITIES
# =============================================================================

module "identity" {
  source = "./modules/identity"

  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  name_prefix         = local.name_prefix
  tags                = local.tags

  aks_oidc_issuer_url     = module.aks.oidc_issuer_url
  keyvault_id             = module.keyvault.id
  dns_zone_id             = data.azurerm_dns_zone.main.id
  dns_zone_resource_group = local.dns.zone_resource_group

  depends_on = [module.aks, module.keyvault]
}

# =============================================================================
# KUBERNETES DEPLOYMENTS
# =============================================================================

module "kubernetes" {
  source = "./kubernetes"

  name_prefix = local.name_prefix
  domain_name = local.dns.zone_name
  environment = local.environment

  # Azure context
  subscription_id         = data.azurerm_subscription.current.subscription_id
  tenant_id               = data.azurerm_subscription.current.tenant_id
  dns_zone_resource_group = local.dns.zone_resource_group

  # Key Vault
  keyvault_uri = module.keyvault.vault_uri

  # ACR
  acr_login_server = module.acr.login_server

  # Identities
  external_dns_identity_client_id     = module.identity.external_dns_identity_client_id
  external_secrets_identity_client_id = module.identity.external_secrets_identity_client_id

  # Configuration
  cert_manager_email = local.dns.cert_manager_email
  helm_versions      = local.helm_versions

  # ArgoCD
  argocd_github_org           = local.argocd.github_org
  argocd_admin_users          = local.argocd.admin_users
  argocd_github_client_id     = var.argocd_github_client_id
  argocd_github_client_secret = var.argocd_github_client_secret

  # Security Policies
  enable_kyverno              = local.security.enable_kyverno
  enable_kyverno_policies     = local.security.enable_kyverno_policies
  enable_cilium_policies      = local.security.enable_cilium_policies
  enable_registry_restriction = local.security.enable_registry_restriction
  allowed_registries          = local.security.allowed_registries

  depends_on = [
    module.aks,
    module.identity,
    module.keyvault,
    module.acr,
  ]
}
