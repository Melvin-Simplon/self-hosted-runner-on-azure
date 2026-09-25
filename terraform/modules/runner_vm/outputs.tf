output "public_ip" {
  description = "Public IP of the VM, used as the Ansible inventory host"
  value       = azurerm_public_ip.this.ip_address
}

output "admin_username" {
  description = "Sudo SSH user reserved to Ansible"
  value       = var.admin_username
}
