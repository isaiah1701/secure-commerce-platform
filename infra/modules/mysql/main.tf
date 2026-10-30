resource "azurerm_mysql_flexible_server" "main" {
  #checkov:skip=CKV_AZURE_94:Geo-redundant backups are excluded for this single-region training lab; seven-day local backups remain enabled.
  #checkov:skip=CKV2_AZURE_56:Azure MySQL Flexible Server private access uses a delegated subnet and private DNS; a separate Private Link endpoint is not applicable.
  name                         = var.name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  version                      = "8.0.21"
  delegated_subnet_id          = var.delegated_subnet_id
  private_dns_zone_id          = var.private_dns_zone_id
  public_network_access        = "Disabled"
  administrator_login          = var.administrator_login
  administrator_password       = var.administrator_password
  sku_name                     = var.sku_name
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  tags                         = var.tags

  storage {
    size_gb           = 20
    auto_grow_enabled = true
  }

  lifecycle {
    ignore_changes = [zone]
  }
}

resource "azurerm_mysql_flexible_database" "glpi" {
  name                = var.database_name
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.main.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

resource "azurerm_mysql_flexible_server_configuration" "require_secure_transport" {
  name                = "require_secure_transport"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.main.name
  value               = "ON"
}

resource "azurerm_monitor_diagnostic_setting" "main" {
  name                       = "send-to-log-analytics"
  target_resource_id         = azurerm_mysql_flexible_server.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
