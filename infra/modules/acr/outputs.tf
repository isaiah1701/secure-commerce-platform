output "acr_id" {
  description = "Azure Container Registry resource ID."
  value       = azurerm_container_registry.main.id
}

output "acr_name" {
  description = "Azure Container Registry name."
  value       = azurerm_container_registry.main.name
}

output "acr_login_server" {
  description = "Azure Container Registry login server."
  value       = azurerm_container_registry.main.login_server
}

output "identity_id" {
  description = "User-assigned app identity resource ID."
  value       = azurerm_user_assigned_identity.app.id
}

output "identity_principal_id" {
  description = "User-assigned app identity principal ID."
  value       = azurerm_user_assigned_identity.app.principal_id
}
