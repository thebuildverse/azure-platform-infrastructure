# =============================================================================
# VIRTUAL NETWORK
# =============================================================================

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.name_prefix}"
  address_space       = var.vnet_address_space
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# =============================================================================
# SUBNETS
# =============================================================================

resource "azurerm_subnet" "nodes" {
  name                 = var.subnets.nodes.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnets.nodes.prefix]

  service_endpoints = [
    "Microsoft.ContainerRegistry",
    "Microsoft.KeyVault",
    "Microsoft.Storage",
  ]
}

resource "azurerm_subnet" "pods" {
  name                 = var.subnets.pods.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnets.pods.prefix]

  delegation {
    name = "aks-delegation"
    service_delegation {
      name    = "Microsoft.ContainerService/managedClusters"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# =============================================================================
# NETWORK SECURITY GROUPS
# =============================================================================

resource "azurerm_network_security_group" "nodes" {
  name                = "nsg-${var.name_prefix}-nodes"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_group" "pods" {
  name                = "nsg-${var.name_prefix}-pods"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Allow HTTPS outbound for nodes (required for AKS control plane)
resource "azurerm_network_security_rule" "nodes_allow_https_outbound" {
  name                        = "AllowHTTPSOutbound"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nodes.name
}

# Allow DNS outbound for nodes
resource "azurerm_network_security_rule" "nodes_allow_dns_outbound" {
  name                        = "AllowDNSOutbound"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nodes.name
}

# Allow NTP outbound for nodes
resource "azurerm_network_security_rule" "nodes_allow_ntp_outbound" {
  name                        = "AllowNTPOutbound"
  priority                    = 120
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "123"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nodes.name
}

# Allow HTTP outbound for cert-manager ACME challenges
resource "azurerm_network_security_rule" "nodes_allow_http_outbound" {
  name                        = "AllowHTTPOutbound"
  priority                    = 130
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nodes.name
}

# Allow HTTP inbound to nodes
resource "azurerm_network_security_rule" "nodes_allow_http_inbound" {
  name                        = "AllowHTTPInbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nodes.name
}

# Allow HTTPS inbound to nodes
resource "azurerm_network_security_rule" "nodes_allow_https_inbound" {
  name                        = "AllowHTTPSInbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nodes.name
}

# =============================================================================
# NSG ASSOCIATIONS
# =============================================================================

resource "azurerm_subnet_network_security_group_association" "nodes" {
  subnet_id                 = azurerm_subnet.nodes.id
  network_security_group_id = azurerm_network_security_group.nodes.id
}

resource "azurerm_subnet_network_security_group_association" "pods" {
  subnet_id                 = azurerm_subnet.pods.id
  network_security_group_id = azurerm_network_security_group.pods.id
}
