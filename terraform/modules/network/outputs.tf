output "subnet_id" {
  description = "ID of the runner subnet, used by the VM network interface"
  value       = azurerm_subnet.this.id
}

output "nsg_name" {
  description = "Name of the NSG, used by the workflow to open SSH temporarily"
  value       = azurerm_network_security_group.this.name
}
