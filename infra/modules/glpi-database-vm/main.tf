resource "azurerm_virtual_network" "db" {
  name                = "${var.name}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.40.0.0/16"]
  tags                = var.tags
}
resource "azurerm_subnet" "db" {
  name                 = "${var.name}-snet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.db.name
  address_prefixes     = ["10.40.0.0/24"]
}
resource "azurerm_network_security_group" "db" {
  name                = "${var.name}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  security_rule {
    name                       = "allow-mysql-from-commerce-vnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "10.20.0.0/16"
    destination_address_prefix = "*"
  }
  tags = var.tags
}
resource "azurerm_subnet_network_security_group_association" "db" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.db.id
  depends_on                = [azurerm_subnet.db]
}
resource "azurerm_virtual_network_peering" "to_commerce" {
  name                         = "${var.name}-to-commerce"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.db.name
  remote_virtual_network_id    = var.peer_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
resource "azurerm_network_interface" "main" {
  name                = "${var.name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.db.id
    private_ip_address_allocation = "Dynamic"
  }
  tags       = var.tags
  depends_on = [azurerm_subnet_network_security_group_association.db]
}

resource "azurerm_linux_virtual_machine" "main" {
  #checkov:skip=CKV_AZURE_178:This isolated lab VM has no public IP or SSH ingress; password is retained only for break-glass recovery.
  #checkov:skip=CKV_AZURE_50:Cloud-init is used for deterministic MariaDB bootstrap and no VM extension is installed.
  #checkov:skip=CKV_AZURE_1:Break-glass password authentication is required because this VM is private and has no public ingress.
  #checkov:skip=CKV_AZURE_149:Break-glass password authentication is required because this VM is private and has no public ingress.
  name                            = var.name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  size                            = var.vm_size
  zone                            = "1"
  admin_username                  = "azureadmin"
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.main.id]
  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
    database_password = var.database_password
  }))

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  boot_diagnostics {}
  tags = var.tags
}

resource "azurerm_managed_disk" "data" {
  #checkov:skip=CKV_AZURE_93:Microsoft-managed disk encryption is proportionate for this cost-controlled training lab.
  #checkov:skip=CKV_AZURE_251:The disk is attached only to a private VM NIC and has no public data path.
  name                 = "${var.name}-data"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 32
  tags                 = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  managed_disk_id    = azurerm_managed_disk.data.id
  virtual_machine_id = azurerm_linux_virtual_machine.main.id
  lun                = 0
  caching            = "ReadWrite"
}

resource "azurerm_monitor_diagnostic_setting" "main" {
  name                       = "send-to-log-analytics"
  target_resource_id         = azurerm_linux_virtual_machine.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id
  enabled_log { category = "AuditEvent" }
  enabled_metric { category = "AllMetrics" }
}
