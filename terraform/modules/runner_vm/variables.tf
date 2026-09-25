variable "name_prefix" {
  description = "Suffix used in resource names (vm-<prefix>, nic-<prefix>, pip-<prefix>)"
  type        = string
}

variable "location" {
  description = "Azure region of the resources"
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group hosting the VM"
  type        = string
}

variable "subnet_id" {
  description = "Subnet of the VM network interface, from the network module"
  type        = string
}

variable "vm_size" {
  description = "VM size, must have a local NVMe disk to host the ephemeral OS disk"
  type        = string
  default     = "Standard_D4alds_v7"

  validation {
    # v6/v7 sizes with a "d" (local disk): D4alds_v7, D8ds_v6, F4ads_v7...
    condition     = can(regex("^Standard_[DF][0-9]+[a-z]*d[a-z]*_v[67]$", var.vm_size))
    error_message = "vm_size must be a v6 or v7 size with a local disk (a \"d\" in the name), for example Standard_D4alds_v7."
  }
}

variable "zone" {
  description = "Availability zone of the VM and its public IP (v6 sizes are blocked in zone 3 on this subscription)"
  type        = string
  default     = "1"
}

variable "admin_username" {
  description = "Sudo account created by Azure, reserved to Ansible. CI jobs never use it."
  type        = string
  default     = "ansible"

  validation {
    # A generic name hides who uses this root-equivalent account
    condition     = !contains(["azureuser", "admin", "root", "ubuntu"], var.admin_username)
    error_message = "admin_username must name its single user (default: ansible), not a generic admin account."
  }
}

variable "ssh_public_key" {
  description = "SSH public key of the admin user, the private key stays in a GitHub secret"
  type        = string

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa) AAAA", var.ssh_public_key))
    error_message = "ssh_public_key must be an OpenSSH public key (ssh-ed25519 or ssh-rsa)."
  }
}

variable "tags" {
  description = "Tags applied to every resource"
  type        = map(string)
  default     = {}
}
