locals {
  dns_enabled     = trimspace(var.domain_name) != ""
  binding_enabled = local.dns_enabled && var.enable_custom_domain_binding
  custom_hostname = "${var.app_subdomain}.${var.domain_name}"
  hostname        = local.binding_enabled ? local.custom_hostname : var.container_app_fqdn
}

resource "azurerm_dns_zone" "main" {
  count = local.dns_enabled ? 1 : 0

  name                = var.domain_name
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_dns_cname_record" "app" {
  count = local.dns_enabled ? 1 : 0

  name                = var.app_subdomain
  zone_name           = azurerm_dns_zone.main[0].name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  record              = var.container_app_fqdn
}

resource "azurerm_dns_txt_record" "verification" {
  count = local.dns_enabled ? 1 : 0

  name                = "asuid.${var.app_subdomain}"
  zone_name           = azurerm_dns_zone.main[0].name
  resource_group_name = var.resource_group_name
  ttl                 = 300

  record {
    value = var.custom_domain_verification_id
  }
}

resource "azurerm_container_app_custom_domain" "app" {
  count = local.binding_enabled ? 1 : 0

  name             = local.custom_hostname
  container_app_id = var.container_app_id

  lifecycle {
    # Azure fills these after issuing the managed certificate asynchronously.
    ignore_changes = [certificate_binding_type, container_app_environment_certificate_id]
  }

  depends_on = [
    azurerm_dns_cname_record.app,
    azurerm_dns_txt_record.verification
  ]
}
