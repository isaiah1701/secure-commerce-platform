output "application_url" {
  description = "HTTPS URL using the custom hostname after its managed certificate binding is enabled."
  value       = "https://${local.hostname}"
}

output "dns_zone_name_servers" {
  description = "Azure DNS nameservers for registrar delegation."
  value       = local.dns_enabled ? azurerm_dns_zone.main[0].name_servers : []
}
