variable "name_prefix" {
  description = "Suffix used in resource names (vnet-<prefix>, snet-<prefix>, nsg-<prefix>)"
  type        = string
}

variable "location" {
  description = "Azure region of the resources"
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group hosting the network"
  type        = string
}

variable "address_space" {
  description = "Address space of the VNet"
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "subnet_prefix" {
  description = "CIDR of the runner subnet, must be inside address_space"
  type        = string
  default     = "10.10.1.0/24"

  validation {
    # cidrhost() fails on anything that is not a valid CIDR
    condition     = can(cidrhost(var.subnet_prefix, 0))
    error_message = "subnet_prefix must be a valid CIDR, for example 10.10.1.0/24."
  }
}

variable "tags" {
  description = "Tags applied to every taggable resource"
  type        = map(string)
  default     = {}
}
