data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

locals {
  # Makes the runner resources easy to spot in the portal and in the cost analysis
  common_tags = {
    project     = "self-hosted-runner-on-azure"
    environment = "dev"
    managed_by  = "terraform"
  }
}

module "network" {
  source = "../../modules/network"

  name_prefix         = var.name_prefix
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = local.common_tags
}

module "runner_vm" {
  source = "../../modules/runner_vm"

  name_prefix         = var.name_prefix
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  subnet_id           = module.network.subnet_id
  vm_size             = var.vm_size
  ssh_public_key      = var.ssh_public_key
  tags                = local.common_tags
}
