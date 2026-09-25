# Plan-only tests with a mocked provider: nothing is created on Azure
mock_provider "azurerm" {
  mock_data "azurerm_resource_group" {
    defaults = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mpetitRG"
      location = "francecentral"
    }
  }
}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  # Throwaway public key, its private key was never kept
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC+Uu8Rtusw+fV0sODSXzm6jqQE1rm0LvJ2i7sSohvyy test"
}

run "outputs_expose_what_the_workflows_need" {
  command = plan

  assert {
    condition     = output.nsg_name == "nsg-runner"
    error_message = "nsg_name output must name the NSG the workflow opens for SSH"
  }

  assert {
    condition     = output.admin_username == "ansible"
    error_message = "admin_username output must be the ansible account"
  }

  assert {
    condition     = output.resource_group_name == "mpetitRG"
    error_message = "resource_group_name output is needed by az network nsg rule create"
  }
}

run "every_resource_is_tagged" {
  command = plan

  assert {
    condition     = local.common_tags["managed_by"] == "terraform" && local.common_tags["project"] == "self-hosted-runner-on-azure"
    error_message = "Common tags must identify the project and Terraform"
  }
}
