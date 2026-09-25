output "client_id" {
  description = "Client ID of the GitHub identity, for the AZURE_CLIENT_ID secret"
  value       = azurerm_user_assigned_identity.github.client_id
}

output "tenant_id" {
  description = "Tenant ID, for the AZURE_TENANT_ID secret"
  value       = azurerm_user_assigned_identity.github.tenant_id
}

output "subscription_id" {
  description = "Subscription ID, for the AZURE_SUBSCRIPTION_ID secret"
  value       = var.subscription_id
}
