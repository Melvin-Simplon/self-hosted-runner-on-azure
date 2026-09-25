# Plan-only tests with a mocked provider: nothing is created on Azure
mock_provider "azurerm" {}

variables {
  name_prefix         = "runner"
  location            = "francecentral"
  resource_group_name = "rg-test"
  subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-runner/subnets/snet-runner"
  # Throwaway public key, its private key was never kept
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC+Uu8Rtusw+fV0sODSXzm6jqQE1rm0LvJ2i7sSohvyy test"
}

run "defaults_match_the_chosen_size" {
  command = plan

  assert {
    condition     = azurerm_linux_virtual_machine.this.size == "Standard_D2s_v3"
    error_message = "Default size must be Standard_D2s_v3, the only size allowed by the school policy with an ephemeral OS disk"
  }

  assert {
    condition     = azurerm_linux_virtual_machine.this.name == "vm-runner"
    error_message = "VM name must be vm-<name_prefix>"
  }
}

run "ssh_key_only" {
  command = plan

  assert {
    condition     = azurerm_linux_virtual_machine.this.disable_password_authentication == true
    error_message = "Password authentication must be disabled"
  }
}

run "os_disk_is_ephemeral_on_cache_disk" {
  command = plan

  assert {
    condition     = azurerm_linux_virtual_machine.this.os_disk[0].diff_disk_settings[0].placement == "CacheDisk"
    error_message = "OS disk must be ephemeral on the local cache disk"
  }
}

run "public_ip_is_static_in_vm_zone" {
  command = plan

  assert {
    condition     = azurerm_public_ip.this.allocation_method == "Static" && azurerm_public_ip.this.sku == "Standard"
    error_message = "Public IP must be Standard and Static"
  }

  assert {
    condition     = one(tolist(azurerm_public_ip.this.zones)) == azurerm_linux_virtual_machine.this.zone
    error_message = "Public IP must be in the same zone as the VM"
  }
}

run "rejects_size_denied_by_policy" {
  command = plan

  # Refused at apply time by the school Azure Policy (RequestDisallowedByPolicy)
  variables {
    vm_size = "Standard_D4alds_v7"
  }

  expect_failures = [var.vm_size]
}

run "rejects_invalid_ssh_key" {
  command = plan

  variables {
    ssh_public_key = "not-a-key"
  }

  expect_failures = [var.ssh_public_key]
}

run "admin_user_is_ansible" {
  command = plan

  # Only Ansible uses this sudo account; CI jobs run as an unprivileged user created by Ansible
  assert {
    condition     = azurerm_linux_virtual_machine.this.admin_username == "ansible"
    error_message = "Admin user must be ansible, not a generic admin account"
  }
}

run "rejects_generic_admin_names" {
  command = plan

  variables {
    admin_username = "azureuser"
  }

  expect_failures = [var.admin_username]
}
