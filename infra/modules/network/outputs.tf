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
