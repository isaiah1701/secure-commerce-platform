output "key_vault_id" {
  description = "Key Vault resource ID."
  value       = azurerm_key_vault.main.id
}

output "database_url_secret_id" {
  description = "Versionless Key Vault secret ID for DATABASE_URL."
  value       = azurerm_key_vault_secret.database_url.versionless_id
}

output "jwt_secret_id" {
  description = "Versionless Key Vault secret ID for JWT_SECRET."
  value       = azurerm_key_vault_secret.jwt_secret.versionless_id
}

output "application_insights_connection_string_secret_id" {
  description = "Versionless Key Vault secret ID for the Application Insights connection string."
  value       = azurerm_key_vault_secret.application_insights.versionless_id
}
