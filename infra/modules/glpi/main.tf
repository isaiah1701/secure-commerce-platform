resource "azurerm_user_assigned_identity" "app" {
  name                = "${var.name_prefix}-glpi-mi"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "key_vault_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_key_vault_secret" "database_password" {
  #checkov:skip=CKV_AZURE_41:Database password rotation is coordinated with the GLPI database and application deployment.
  name         = "glpi-database-password"
  value        = var.database_password
  key_vault_id = var.key_vault_id
  content_type = "password"
}

resource "azurerm_storage_account" "files" {
  #checkov:skip=CKV_AZURE_206:LRS is an explicit cost choice for this personal lab; backups are handled at the application/database layer.
  #checkov:skip=CKV_AZURE_33:Queue logging is irrelevant because this account is used only for Azure Files.
  #checkov:skip=CKV_AZURE_59:Container Apps Azure Files requires a reachable storage endpoint; access requires the storage key and the share is not public.
  #checkov:skip=CKV2_AZURE_40:Container Apps Azure Files integration requires shared-key authorization for the environment storage binding.
  #checkov:skip=CKV2_AZURE_38:Soft delete is not supported for Azure Files through this provider configuration; the database and app data are separately backed up.
  #checkov:skip=CKV2_AZURE_41:SAS expiration policy is not used because the workload authenticates with the storage account key.
  #checkov:skip=CKV2_AZURE_33:Private endpoint would require additional Container Apps storage networking and is excluded from this cost-controlled lab.
  #checkov:skip=CKV2_AZURE_1:Microsoft-managed encryption is proportionate for this lab; customer-managed keys would add bootstrap complexity and cost.
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

resource "azurerm_storage_share" "glpi" {
  name               = "glpi-data"
  storage_account_id = azurerm_storage_account.files.id
  quota              = 10
}

resource "azurerm_container_app_environment_storage" "glpi" {
  name                         = "glpi-data"
  container_app_environment_id = var.container_app_environment_id
  account_name                 = azurerm_storage_account.files.name
  access_key                   = azurerm_storage_account.files.primary_access_key
  share_name                   = azurerm_storage_share.glpi.name
  access_mode                  = "ReadWrite"
}

resource "azurerm_container_app" "main" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = var.container_app_environment_id
  revision_mode                = "Single"
  max_inactive_revisions       = 2
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  secret {
    name                = "database-password"
    identity            = azurerm_user_assigned_identity.app.id
    key_vault_secret_id = azurerm_key_vault_secret.database_password.versionless_id
  }

  ingress {
    external_enabled           = true
    allow_insecure_connections = false
    target_port                = 80
    transport                  = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    volume {
      name         = "glpi-data"
      storage_name = azurerm_container_app_environment_storage.glpi.name
      storage_type = "AzureFile"
    }

    container {
      name   = "glpi"
      image  = var.image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "GLPI_DB_HOST"
        value = var.database_host
      }
      env {
        name  = "GLPI_DB_PORT"
        value = "3306"
      }
      env {
        name  = "GLPI_DB_NAME"
        value = var.database_name
      }
      env {
        name  = "GLPI_DB_USER"
        value = var.database_user
      }
      env {
        name  = "GLPI_DB_SSL"
        value = "false"
      }
      env {
        name  = "GLPI_SKIP_AUTOINSTALL"
        value = "false"
      }
      env {
        name  = "GLPI_SKIP_AUTOUPDATE"
        value = "false"
      }
      env {
        name  = "GLPI_CRONTAB_ENABLED"
        value = "1"
      }
      env {
        name  = "GLPI_ENVIRONMENT_TYPE"
        value = "production"
      }
      env {
        name        = "GLPI_DB_PASSWORD"
        secret_name = "database-password"
      }

      volume_mounts {
        name = "glpi-data"
        path = "/var/glpi"
      }

    }
  }
}

resource "azurerm_dns_cname_record" "ticket" {
  count = var.domain_name == "" ? 0 : 1

  name                = var.subdomain
  zone_name           = var.domain_name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  record              = azurerm_container_app.main.ingress[0].fqdn
}

resource "azurerm_dns_txt_record" "verification" {
  count = var.domain_name == "" ? 0 : 1

  name                = "asuid.${var.subdomain}"
  zone_name           = var.domain_name
  resource_group_name = var.resource_group_name
  ttl                 = 300

  record { value = azurerm_container_app.main.custom_domain_verification_id }
}

resource "azurerm_container_app_custom_domain" "ticket" {
  count = var.domain_name == "" ? 0 : 1

  name             = "${var.subdomain}.${var.domain_name}"
  container_app_id = azurerm_container_app.main.id

  lifecycle {
    ignore_changes = [certificate_binding_type, container_app_environment_certificate_id]
  }

  depends_on = [azurerm_dns_cname_record.ticket, azurerm_dns_txt_record.verification]
}
