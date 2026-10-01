variable "subscription_id" {
  description = "ID of the Azure subscription hosting the resource group"
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group of the runner, AZURE_RESOURCE_GROUP in .env"
  type        = string
}

variable "github_repository" {
  description = "Repository (owner/name) whose workflows get the Azure identity, taken from the origin remote"
  type        = string
}