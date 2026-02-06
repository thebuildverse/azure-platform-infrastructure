# =============================================================================
# AZURE AD GROUPS
# =============================================================================

resource "azuread_group" "cluster_admins" {
  display_name     = "aks-admins-${var.name_prefix}"
  security_enabled = true
}

resource "azuread_group" "cluster_writers" {
  display_name     = "aks-writers-${var.name_prefix}"
  security_enabled = true
}

resource "azuread_group" "cluster_readers" {
  display_name     = "aks-readers-${var.name_prefix}"
  security_enabled = true
}

# =============================================================================
# AKS CLUSTER
# =============================================================================

resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "aks-${var.name_prefix}"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier
  tags                = var.tags

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name                        = var.default_node_pool.name
    vm_size                     = var.default_node_pool.vm_size
    os_sku                      = var.default_node_pool.os_sku
    os_disk_size_gb             = var.default_node_pool.os_disk_size_gb
    os_disk_type                = "Managed"
    vnet_subnet_id              = var.node_subnet_id
    pod_subnet_id               = var.pod_subnet_id
    temporary_name_for_rotation = "temppool"

    node_count          = var.default_node_pool.enable_auto_scaling ? null : var.default_node_pool.node_count
    auto_scaling_enabled = var.default_node_pool.enable_auto_scaling
    min_count           = var.default_node_pool.enable_auto_scaling ? var.default_node_pool.min_count : null
    max_count           = var.default_node_pool.enable_auto_scaling ? var.default_node_pool.max_count : null

    upgrade_settings {
      max_surge                     = "33%"
      drain_timeout_in_minutes      = 30
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "azure"
    network_policy     = "cilium"
    network_data_plane = "cilium"
    load_balancer_sku  = "standard"
    outbound_type      = "loadBalancer"
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    admin_group_object_ids = [azuread_group.cluster_admins.object_id]
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  monitor_metrics {}

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count, # Ignore if using autoscaler
    ]
  }
}

# =============================================================================
# RBAC ROLE ASSIGNMENTS
# =============================================================================

resource "azurerm_role_assignment" "cluster_admin" {
  principal_id         = azuread_group.cluster_admins.object_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  scope                = azurerm_kubernetes_cluster.main.id
}

resource "azurerm_role_assignment" "cluster_writer" {
  principal_id         = azuread_group.cluster_writers.object_id
  role_definition_name = "Azure Kubernetes Service RBAC Writer"
  scope                = azurerm_kubernetes_cluster.main.id
}

resource "azurerm_role_assignment" "cluster_reader" {
  principal_id         = azuread_group.cluster_readers.object_id
  role_definition_name = "Azure Kubernetes Service RBAC Reader"
  scope                = azurerm_kubernetes_cluster.main.id
}

# =============================================================================
# DIAGNOSTIC SETTINGS
# =============================================================================

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "diag-${azurerm_kubernetes_cluster.main.name}"
  target_resource_id         = azurerm_kubernetes_cluster.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-audit"
  }

  enabled_log {
    category = "kube-audit-admin"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "kube-scheduler"
  }

  enabled_log {
    category = "cluster-autoscaler"
  }

  enabled_log {
    category = "guard"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
