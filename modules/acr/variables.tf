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

variable "sku" {
  description = "ACR SKU (Basic, Standard, or Premium)"
  type        = string
  default     = "Basic"
}

variable "admin_enabled" {
  description = "Enable admin user for ACR"
  type        = bool
  default     = false
}

variable "aks_kubelet_identity_id" {
  description = "AKS kubelet managed identity object ID for ACR pull"
  type        = string
}

variable "geo_replications" {
  description = "Geo-replication locations (Premium SKU only)"
  type = list(object({
    location                = string
    zone_redundancy_enabled = bool
  }))
  default = []
}
