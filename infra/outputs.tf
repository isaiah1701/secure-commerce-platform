output "resource_group_name" {
  description = "Azure resource group containing the platform."
  value       = azurerm_resource_group.main.name
}

output "container_app_name" {
  description = "Azure Container App name."
  value       = module.container_app.container_app_name
}

output "container_app_fqdn" {
  description = "Default Azure Container Apps hostname."
  value       = module.container_app.container_app_fqdn
}

output "application_url" {
  description = "Public application URL, using the custom hostname when configured."
  value       = module.dns.application_url
}

output "acr_login_server" {
  description = "Azure Container Registry login server."
  value       = module.acr.acr_login_server
}

output "acr_name" {
  description = "Azure Container Registry name."
  value       = module.acr.acr_name
}

output "postgres_host" {
  description = "Private PostgreSQL Flexible Server hostname."
  value       = module.postgres.postgres_fqdn
}

output "log_analytics_workspace_name" {
  description = "Log Analytics workspace used by Container Apps and later Sentinel."
  value       = module.monitoring.log_analytics_workspace_name
}

output "application_insights_name" {
  description = "Workspace-based Application Insights resource name."
  value       = module.monitoring.application_insights_name
}

output "dns_name_servers" {
  description = "Azure DNS nameservers to configure at an external registrar. Empty when domain_name is unset."
  value       = module.dns.dns_zone_name_servers
}

output "glpi_application_url" {
  description = "GLPI ticketing URL."
  value       = var.enable_glpi ? module.glpi[0].application_url : null
}

output "glpi_container_app_fqdn" {
  description = "Default GLPI Container Apps hostname."
  value       = var.enable_glpi ? module.glpi[0].container_app_fqdn : null
}

output "glpi_database_private_ip" {
  description = "Private IP of the isolated GLPI MariaDB VM."
  value       = var.enable_glpi ? module.glpi_database_vm[0].private_ip_address : null
}
