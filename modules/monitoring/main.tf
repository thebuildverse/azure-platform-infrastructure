# =============================================================================
# AZURE MONITOR WORKSPACE (Prometheus)
# =============================================================================

resource "azurerm_monitor_workspace" "main" {
  name                = "amon-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# =============================================================================
# DATA COLLECTION
# =============================================================================

resource "azurerm_monitor_data_collection_endpoint" "main" {
  name                          = "dce-${var.name_prefix}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  kind                          = "Linux"
  public_network_access_enabled = true
  tags                          = var.tags
}

resource "azurerm_monitor_data_collection_rule" "prometheus" {
  name                        = "dcr-prometheus-${var.name_prefix}"
  resource_group_name         = var.resource_group_name
  location                    = var.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.main.id
  tags                        = var.tags

  data_sources {
    prometheus_forwarder {
      name    = "PrometheusDataSource"
      streams = ["Microsoft-PrometheusMetrics"]
    }
  }

  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.main.id
      name               = azurerm_monitor_workspace.main.name
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = [azurerm_monitor_workspace.main.name]
  }
}

resource "azurerm_monitor_data_collection_rule_association" "dcr_aks" {
  name                    = "dcra-prometheus-${var.name_prefix}"
  target_resource_id      = var.aks_cluster_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.prometheus.id
}

resource "azurerm_monitor_data_collection_rule_association" "dce_aks" {
  target_resource_id          = var.aks_cluster_id
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.main.id
}

# =============================================================================
# AZURE MANAGED GRAFANA
# =============================================================================

resource "azurerm_dashboard_grafana" "main" {
  name                              = "amg-${var.name_prefix}"
  resource_group_name               = var.resource_group_name
  location                          = var.location
  sku                               = var.grafana_sku
  grafana_major_version             = var.grafana_major_version
  zone_redundancy_enabled           = false
  public_network_access_enabled     = true
  api_key_enabled                   = true
  deterministic_outbound_ip_enabled = false
  tags                              = var.tags

  identity {
    type = "SystemAssigned"
  }

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.main.id
  }
}

# Grant Grafana access to Azure Monitor workspace
resource "azurerm_role_assignment" "grafana_monitor_reader" {
  scope                = azurerm_monitor_workspace.main.id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = azurerm_dashboard_grafana.main.identity[0].principal_id
}

# Grant Grafana access to Log Analytics
resource "azurerm_role_assignment" "grafana_log_reader" {
  scope                = var.log_analytics_workspace_id
  role_definition_name = "Log Analytics Reader"
  principal_id         = azurerm_dashboard_grafana.main.identity[0].principal_id
}
