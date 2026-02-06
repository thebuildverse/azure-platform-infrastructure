variable "name_prefix" {
  description = "Prefix for resource names (used in group display names)"
  type        = string
}

variable "keyvault_id" {
  description = "Azure Key Vault resource ID for role assignments"
  type        = string
}

variable "grafana_id" {
  description = "Azure Managed Grafana resource ID for role assignments"
  type        = string
}

variable "monitor_workspace_id" {
  description = "Azure Monitor workspace resource ID for role assignments"
  type        = string
}
