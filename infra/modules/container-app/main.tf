resource "azurerm_container_app_environment" "main" {
  name                       = var.environment_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  infrastructure_subnet_id   = var.infrastructure_subnet_id
  logs_destination           = "log-analytics"
  log_analytics_workspace_id = var.log_analytics_workspace_id
  zone_redundancy_enabled    = false
  tags                       = var.tags
}

resource "azurerm_container_app" "main" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = azurerm_container_app_environment.main.id
  revision_mode                = "Single"
  max_inactive_revisions       = 2
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_id]
  }

  registry {
    server   = var.acr_login_server
    identity = var.identity_id
  }

  secret {
    name                = "database-url"
    identity            = var.identity_id
    key_vault_secret_id = var.database_url_secret_id
  }

  secret {
    name                = "jwt-secret"
    identity            = var.identity_id
    key_vault_secret_id = var.jwt_secret_id
  }

  secret {
    name                = "application-insights"
    identity            = var.identity_id
    key_vault_secret_id = var.application_insights_connection_string_secret_id
  }

  ingress {
    external_enabled           = true
    allow_insecure_connections = false
    target_port                = 8000
    transport                  = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "secure-commerce"
      image  = var.container_image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name        = "DATABASE_URL"
        secret_name = "database-url"
      }

      env {
        name        = "JWT_SECRET"
        secret_name = "jwt-secret"
      }

      env {
        name        = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        secret_name = "application-insights"
      }

      env {
        name  = "ENVIRONMENT"
        value = "production"
      }

      env {
        name  = "LOG_LEVEL"
        value = "INFO"
      }

      env {
        name  = "CORS_ORIGINS"
        value = "[]"
      }

      liveness_probe {
        transport               = "HTTP"
        path                    = "/health"
        port                    = 8000
        initial_delay           = 30
        interval_seconds        = 30
        timeout                 = 5
        failure_count_threshold = 3
      }

      readiness_probe {
        transport               = "HTTP"
        path                    = "/ready"
        port                    = 8000
        interval_seconds        = 15
        timeout                 = 5
        failure_count_threshold = 5
        success_count_threshold = 1
      }
    }
  }

  lifecycle {
    # Application CD owns the immutable SHA image after Terraform creates the app.
    ignore_changes = [template[0].container[0].image]
  }
}
