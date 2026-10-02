terraform {
  required_version = "~> 1.15"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.7"
    }
  }
}

# Auth comes from `az login` on the workstation
provider "azurerm" {
  subscription_id = var.subscription_id

  # Only Reader on the subscription: registering resource providers would fail
  resource_provider_registrations = "none"

  features {}
}
