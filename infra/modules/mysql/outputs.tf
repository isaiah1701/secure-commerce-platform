output "mysql_fqdn" {
  value = azurerm_mysql_flexible_server.main.fqdn
}

output "server_id" {
  value = azurerm_mysql_flexible_server.main.id
}
