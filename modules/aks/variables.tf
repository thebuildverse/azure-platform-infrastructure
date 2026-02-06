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

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
}

variable "sku_tier" {
  description = "AKS SKU tier (Free or Standard)"
  type        = string
  default     = "Free"
}

variable "default_node_pool" {
  description = "Default node pool configuration"
  type = object({
    name                = string
    vm_size             = string
    os_disk_size_gb     = number
    os_sku              = string
    enable_auto_scaling = bool
    node_count          = number
    min_count           = number
    max_count           = number
  })
}

variable "node_subnet_id" {
  description = "Subnet ID for AKS nodes"
  type        = string
}

variable "pod_subnet_id" {
  description = "Subnet ID for AKS pods"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostics"
  type        = string
}
