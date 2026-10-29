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
    allow_insecure_connections = false
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
    }
  }
}
