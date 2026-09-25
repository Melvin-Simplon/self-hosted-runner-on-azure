# Static: the IP must not change while the workflow opens SSH for Ansible
resource "azurerm_public_ip" "this" {
  name                = "pip-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [var.zone]
  tags                = var.tags
}

resource "azurerm_network_interface" "this" {
  name                = "nic-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.this.id
  }
}

resource "azurerm_linux_virtual_machine" "this" {
  name                  = "vm-${var.name_prefix}"
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = var.vm_size
  zone                  = var.zone
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.this.id]
  tags                  = var.tags

  # SSH key only, no password on the VM
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  # Ephemeral OS disk on the local cache disk: faster than a network disk and free.
  # Trade-off: the VM cannot be stopped/deallocated, only destroyed (fine, it is on demand).
  os_disk {
    caching              = "ReadOnly" # required for ephemeral disks
    storage_account_type = "Standard_LRS"

    diff_disk_settings {
      option    = "Local"
      placement = "CacheDisk" # 50 GB on D2s_v3, the Ubuntu image needs 30 GB
    }
  }

  # "minimal" is the Gen2 image, D2s_v3 supports Gen1 and Gen2
  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "minimal"
    version   = "latest"
  }

  # Serial console and boot screenshot in the portal, handy if SSH never comes up
  boot_diagnostics {}
}
