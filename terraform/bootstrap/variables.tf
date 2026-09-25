variable "subscription_id" {
  description = "ID of the Azure subscription hosting mpetitRG"
  type        = string
}

variable "resource_group_name" {
  description = "Resource Group Azure"
  type        = string
  default     = "mpetitRG"
}

variable "github_repository" {
  description = "GitHub Repository"
  type        = string
  default     = "Melvin-Simplon/self-hosted-runner-on-azure"
}