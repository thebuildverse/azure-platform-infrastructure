output "vnet_id" {
  description = "Virtual network ID"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Virtual network name"
  value       = azurerm_virtual_network.main.name
}

output "node_subnet_id" {
  description = "Node subnet ID"
  value       = azurerm_subnet.nodes.id
}

output "pod_subnet_id" {
  description = "Pod subnet ID"
  value       = azurerm_subnet.pods.id
}

output "node_nsg_id" {
  description = "Node NSG ID"
  value       = azurerm_network_security_group.nodes.id
}

output "pod_nsg_id" {
  description = "Pod NSG ID"
  value       = azurerm_network_security_group.pods.id
}
