# Read by the workflows after the apply: Ansible inventory and temporary SSH rule

output "public_ip" {
  description = "Public IP of the runner VM"
  value       = module.runner_vm.public_ip
}

output "admin_username" {
  description = "Sudo SSH user reserved to Ansible"
  value       = module.runner_vm.admin_username
}

output "nsg_name" {
  description = "NSG where the workflow adds then removes the SSH rule"
  value       = module.network.nsg_name
}

output "resource_group_name" {
  description = "Resource group of the NSG, needed by az network nsg rule create"
  value       = data.azurerm_resource_group.main.name
}
