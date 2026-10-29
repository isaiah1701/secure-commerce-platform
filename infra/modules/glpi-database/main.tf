resource "azurerm_storage_account" "data" {
  name                            = var.storage_account_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true
  tags                            = var.tags
}
resource "azurerm_storage_share" "data" {
  name               = "mariadb-data"
  storage_account_id = azurerm_storage_account.data.id
  quota              = 20
}
resource "azurerm_container_app_environment_storage" "data" {
  name                         = "glpi-mariadb-data"
  container_app_environment_id = var.container_app_environment_id
  account_name                 = azurerm_storage_account.data.name
  access_key                   = azurerm_storage_account.data.primary_access_key
  share_name                   = azurerm_storage_share.data.name
  access_mode                  = "ReadWrite"
}
resource "azurerm_container_app" "main" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = var.container_app_environment_id
  revision_mode                = "Single"
  tags                         = var.tags
  secret {
    name  = "database-password"
    value = var.database_password
  }
  ingress {
    external_enabled           = false
    allow_insecure_connections = true
    target_port                = 3306
    transport                  = "tcp"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
  template {
    min_replicas = 1
    max_replicas = 1
    volume {
      name         = "mariadb-data"
      storage_name = azurerm_container_app_environment_storage.data.name
      storage_type = "AzureFile"
    }
    container {
      name   = "mariadb"
      image  = var.image
      cpu    = 0.5
      memory = "1Gi"
      env {
        name  = "MARIADB_DATABASE"
        value = var.database_name
      }
      env {
        name  = "MARIADB_USER"
        value = var.database_user
      }
      env {
        name        = "MARIADB_PASSWORD"
        secret_name = "database-password"
      }
      env {
        name        = "MARIADB_ROOT_PASSWORD"
        secret_name = "database-password"
      }
      volume_mounts {
        name = "mariadb-data"
        path = "/var/lib/mysql"
      }
    }
  }
}
resource "azurerm_monitor_diagnostic_setting" "main" {
  name                       = "send-to-log-analytics"
  target_resource_id         = azurerm_container_app.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id
  enabled_log {
    category = "ContainerAppConsoleLogs"
  }
}
