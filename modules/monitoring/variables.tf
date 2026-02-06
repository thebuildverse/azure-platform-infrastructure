variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "aks_cluster_id" {
  description = "AKS cluster resource ID"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID (created externally)"
  type        = string
}

variable "grafana_sku" {
  description = "Grafana SKU (Essential or Standard)"
  type        = string
  default     = "Essential"
}

variable "grafana_major_version" {
  description = "Grafana major version"
  type        = number
  default     = 10
}
