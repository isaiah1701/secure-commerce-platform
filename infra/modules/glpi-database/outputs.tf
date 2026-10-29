output "fqdn" { value = azurerm_container_app.main.ingress[0].fqdn }
output "database_name" { value = var.database_name }
