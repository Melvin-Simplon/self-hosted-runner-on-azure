terraform {
  required_version = "~> 1.15"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.7"
    }
  }
}

# Bootstrap runs from the workstation with `az login`: it creates the OIDC identity, so it cannot use it
provider "azurerm" {
  subscription_id = var.subscription_id

  # Only Reader on the subscription: registering resource providers would fail
  resource_provider_registrations = "none"

  features {}
}
