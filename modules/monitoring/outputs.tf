output "monitor_workspace_id" {
  description = "Azure Monitor workspace ID"
  value       = azurerm_monitor_workspace.main.id
}

output "grafana_id" {
  description = "Grafana resource ID"
  value       = azurerm_dashboard_grafana.main.id
}

output "grafana_endpoint" {
  description = "Grafana endpoint URL"
  value       = azurerm_dashboard_grafana.main.endpoint
}
