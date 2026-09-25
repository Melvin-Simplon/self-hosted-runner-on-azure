# Plan-only tests with a mocked provider: nothing is created on Azure
mock_provider "azurerm" {
  # Random mock IDs are rejected by the association resource, so give them the Azure format
  mock_resource "azurerm_subnet" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-runner/subnets/snet-runner"
    }
  }

  mock_resource "azurerm_network_security_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkSecurityGroups/nsg-runner"
    }
  }
}

variables {
  name_prefix         = "runner"
  location            = "francecentral"
  resource_group_name = "rg-test"
}

run "names_follow_prefix" {
  command = plan

  assert {
    condition     = azurerm_virtual_network.this.name == "vnet-runner"
    error_message = "VNet name must be vnet-<name_prefix>"
  }

  assert {
    condition     = azurerm_network_security_group.this.name == "nsg-runner"
    error_message = "NSG name must be nsg-<name_prefix>"
  }
}

run "nsg_has_no_inline_rule" {
  # security_rule is computed, so it is only known after apply (simulated by the mock)
  command = apply

  # Inline rules would make Terraform delete the temporary SSH rule added by the workflow
  assert {
    condition     = length(azurerm_network_security_group.this.security_rule) == 0
    error_message = "NSG must not declare inline security_rule blocks"
  }
}

run "rejects_invalid_subnet_prefix" {
  command = plan

  variables {
    subnet_prefix = "not-a-cidr"
  }

  expect_failures = [var.subnet_prefix]
}
