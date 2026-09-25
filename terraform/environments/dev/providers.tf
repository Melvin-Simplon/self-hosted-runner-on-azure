terraform {
  required_version = "~> 1.15"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.7"
    }
  }
}

# Auth comes from the environment: `az login` on the workstation,
# ARM_USE_OIDC + ARM_CLIENT_ID + ARM_TENANT_ID in GitHub Actions
provider "azurerm" {
  subscription_id = var.subscription_id

  # Only Reader on the subscription: registering resource providers would fail
  resource_provider_registrations = "none"

  features {}
}
