output "server_id" { value = azurerm_mysql_flexible_server.main.id }
output "fqdn" { value = azurerm_mysql_flexible_server.main.fqdn }
output "database_name" { value = azurerm_mysql_flexible_database.glpi.name }
