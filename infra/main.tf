resource "azurerm_resource_group" "main" {
  name     = "${local.prefix}-rg"
  location = var.location
  tags     = local.tags
}

module "network" {
  source = "./modules/network"

  name_prefix         = local.prefix
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

module "monitoring" {
  source = "./modules/monitoring"

  name_prefix         = local.prefix
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

module "acr" {
  source = "./modules/acr"

  name                           = local.acr_name
  identity_name                  = "${local.prefix}-app-mi"
  location                       = azurerm_resource_group.main.location
  resource_group_name            = azurerm_resource_group.main.name
  log_analytics_workspace_id     = module.monitoring.log_analytics_workspace_id
  deployment_principal_object_id = coalesce(var.deployment_principal_object_id, data.azurerm_client_config.current.object_id)
  tags                           = local.tags
}

module "postgres" {
  source = "./modules/postgres"

  name                       = "${local.prefix}-pg"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  delegated_subnet_id        = module.network.database_subnet_id
  private_dns_zone_id        = module.network.postgres_private_dns_zone_id
  administrator_login        = var.postgres_admin_username
  administrator_password     = var.postgres_admin_password
  database_name              = "commerce"
  sku_name                   = var.postgres_sku_name
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  tags                       = local.tags
}

module "key_vault" {
  source = "./modules/key-vault"

  name                                   = local.key_vault_name
  location                               = azurerm_resource_group.main.location
  resource_group_name                    = azurerm_resource_group.main.name
  tenant_id                              = data.azurerm_client_config.current.tenant_id
  deployment_principal_object_id         = coalesce(var.deployment_principal_object_id, data.azurerm_client_config.current.object_id)
  app_identity_principal_id              = module.acr.identity_principal_id
  postgres_admin_username                = var.postgres_admin_username
  postgres_admin_password                = var.postgres_admin_password
  postgres_fqdn                          = module.postgres.postgres_fqdn
  postgres_database_name                 = module.postgres.postgres_database_name
  jwt_secret                             = var.jwt_secret
  application_insights_connection_string = module.monitoring.application_insights_connection_string
  log_analytics_workspace_id             = module.monitoring.log_analytics_workspace_id
  tags                                   = local.tags
}

module "mysql" {
  count  = var.enable_glpi ? 1 : 0
  source = "./modules/mysql"

  name                       = "${local.prefix}-mysql"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  delegated_subnet_id        = module.network.mysql_subnet_id
  private_dns_zone_id        = module.network.mysql_private_dns_zone_id
  administrator_login        = "glpiadmin"
  administrator_password     = var.glpi_database_password
  database_name              = "glpi"
  sku_name                   = var.glpi_mysql_sku_name
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  tags                       = local.tags
}

module "container_app" {
  source = "./modules/container-app"

  name                                             = "${local.prefix}-app"
  environment_name                                 = "${local.prefix}-cae"
  location                                         = azurerm_resource_group.main.location
  resource_group_name                              = azurerm_resource_group.main.name
  infrastructure_subnet_id                         = module.network.container_apps_subnet_id
  log_analytics_workspace_id                       = module.monitoring.log_analytics_workspace_id
  identity_id                                      = module.acr.identity_id
  acr_login_server                                 = module.acr.acr_login_server
  container_image                                  = "${var.container_image}:${var.container_image_tag}"
  database_url_secret_id                           = module.key_vault.database_url_secret_id
  jwt_secret_id                                    = module.key_vault.jwt_secret_id
  application_insights_connection_string_secret_id = module.key_vault.application_insights_connection_string_secret_id
  min_replicas                                     = var.container_min_replicas
  max_replicas                                     = var.container_max_replicas
  tags                                             = local.tags

  depends_on = [module.key_vault]
}

module "glpi" {
  count  = var.enable_glpi ? 1 : 0
  source = "./modules/glpi"

  name                         = "${local.prefix}-glpi"
  name_prefix                  = "${local.prefix}-glpi"
  location                     = azurerm_resource_group.main.location
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = module.container_app.container_app_environment_id
  acr_id                       = module.acr.acr_id
  acr_login_server             = module.acr.acr_login_server
  key_vault_id                 = module.key_vault.key_vault_id
  database_host                = coalesce(var.glpi_database_host, module.mysql[0].mysql_fqdn)
  database_name                = "glpi"
  database_user                = "glpiadmin"
  database_password            = var.glpi_database_password
  storage_account_name         = substr(replace("${local.compact_name}glpi", "-", ""), 0, 24)
  image                        = var.glpi_image
  domain_name                  = var.domain_name
  subdomain                    = "ticket"
  tags                         = merge(local.tags, { Workload = "glpi-soc" })

}

module "soc" {
  source = "./modules/soc"

  name_prefix                = local.prefix
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  enable                     = var.enable_soc
  tags                       = local.tags
}

module "dns" {
  source = "./modules/dns"

  domain_name                   = var.domain_name
  app_subdomain                 = var.app_subdomain
  enable_custom_domain_binding  = var.enable_custom_domain_binding
  resource_group_name           = azurerm_resource_group.main.name
  container_app_id              = module.container_app.container_app_id
  container_app_fqdn            = module.container_app.container_app_fqdn
  custom_domain_verification_id = module.container_app.custom_domain_verification_id
  tags                          = local.tags
}
