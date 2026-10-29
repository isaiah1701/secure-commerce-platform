output "private_ip_address" { value = azurerm_network_interface.main.private_ip_address }
output "database_host" { value = azurerm_network_interface.main.private_ip_address }
output "vnet_id" { value = azurerm_virtual_network.db.id }
output "vnet_name" { value = azurerm_virtual_network.db.name }
