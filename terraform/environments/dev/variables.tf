variable "subscription_id" {
  description = "ID of the Azure subscription hosting the resource group"
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group, Terraform only reads it (no right to create one)"
  type        = string
  default     = "mpetitRG"
}

variable "name_prefix" {
  description = "Suffix used in every resource name"
  type        = string
  default     = "runner"
}

variable "vm_size" {
  description = "Runner VM size, change it to benchmark another size"
  type        = string
  default     = "Standard_D4alds_v7"
}

variable "ssh_public_key" {
  description = "Public key of the ansible account, from the GitHub variable ANSIBLE_SSH_PUBLIC_KEY"
  type        = string
}
