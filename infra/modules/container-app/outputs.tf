output "container_app_id" {
  description = "Container App resource ID."
  value       = azurerm_container_app.main.id
}

output "container_app_name" {
  description = "Container App name."
  value       = azurerm_container_app.main.name
}

output "container_app_fqdn" {
  description = "Default Container App ingress hostname."
  value       = azurerm_container_app.main.ingress[0].fqdn
}

output "custom_domain_verification_id" {
  description = "Verification ID used by Container Apps custom domains."
  value       = azurerm_container_app.main.custom_domain_verification_id
  sensitive   = true
}

output "container_app_environment_id" {
  description = "Container Apps environment resource ID."
  value       = azurerm_container_app_environment.main.id
}
