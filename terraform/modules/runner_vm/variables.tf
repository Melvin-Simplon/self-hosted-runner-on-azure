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
  description = "VM size, must be allowed by the school Azure Policy and support an ephemeral OS disk"
  type        = string
  default     = "Standard_D2s_v3"

  validation {
    # The policy allows ~20 sizes, but in France Central with this quota only D2s_v3 is
    # both available and able to host an ephemeral OS disk (50 GB cache disk)
    condition     = contains(["Standard_D2s_v3"], var.vm_size)
    error_message = "vm_size must be Standard_D2s_v3: other sizes are denied by the school policy, unavailable, or have no room for an ephemeral OS disk."
  }
}

variable "zone" {
  description = "Availability zone of the VM and its public IP (D2s_v3 is blocked in zone 3 on this subscription)"
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
