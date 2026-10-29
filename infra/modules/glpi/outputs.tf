output "container_app_id" { value = azurerm_container_app.main.id }
output "container_app_fqdn" { value = azurerm_container_app.main.ingress[0].fqdn }
output "application_url" { value = var.domain_name == "" ? "https://${azurerm_container_app.main.ingress[0].fqdn}" : "https://${var.subdomain}.${var.domain_name}" }
output "identity_principal_id" { value = azurerm_user_assigned_identity.app.principal_id }
