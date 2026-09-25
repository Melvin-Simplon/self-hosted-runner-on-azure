resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
  tags                = var.tags
}

# Subnets do not support tags on Azure
resource "azurerm_subnet" "this" {
  name                 = "snet-${var.name_prefix}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_prefix]
}

# No inline security_rule block: the SSH rule is added and removed by the workflow.
# Inline rules would make Terraform delete it on the next apply.
# Without any rule, Azure default rules deny all inbound traffic from the Internet.
resource "azurerm_network_security_group" "this" {
  name                = "nsg-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# The NSG is attached to the subnet, so it covers every VM placed in it
resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}
