output "vnet_id" {
  description = "Virtual network resource ID."
  value       = azurerm_virtual_network.main.id
}

output "container_apps_subnet_id" {
  description = "Container Apps environment subnet resource ID."
  value       = azurerm_subnet.container_apps.id
}

output "database_subnet_id" {
  description = "Delegated PostgreSQL subnet resource ID."
  value       = azurerm_subnet.database.id
}

output "postgres_private_dns_zone_id" {
  description = "PostgreSQL private DNS zone resource ID."
  value       = azurerm_private_dns_zone.postgres.id
}

output "mysql_private_dns_zone_id" {
  description = "Private DNS zone resource ID for the GLPI MySQL server."
  value       = azurerm_private_dns_zone.mysql.id
}

output "mysql_subnet_id" {
  description = "Delegated MySQL Flexible Server subnet resource ID."
  value       = azurerm_subnet.mysql.id
}
