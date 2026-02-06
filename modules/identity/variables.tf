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

variable "aks_oidc_issuer_url" {
  description = "AKS OIDC issuer URL for federated credentials"
  type        = string
}

variable "keyvault_id" {
  description = "Key Vault resource ID"
  type        = string
}

variable "dns_zone_id" {
  description = "DNS Zone resource ID"
  type        = string
}

variable "dns_zone_resource_group" {
  description = "DNS Zone resource group name"
  type        = string
}
