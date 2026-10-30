output "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID."
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Log Analytics workspace name."
  value       = azurerm_log_analytics_workspace.main.name
}

output "log_analytics_workspace_customer_id" {
  description = "Log Analytics workspace customer ID used by the query API."
  value       = azurerm_log_analytics_workspace.main.workspace_id
}

output "application_insights_connection_string" {
  description = "Application Insights connection string."
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

output "application_insights_id" {
  description = "Application Insights resource ID."
  value       = azurerm_application_insights.main.id
}

output "application_insights_name" {
  description = "Application Insights resource name."
  value       = azurerm_application_insights.main.name
}
