locals {
  database_url = "postgresql+psycopg://${var.postgres_admin_username}:${urlencode(var.postgres_admin_password)}@${var.postgres_fqdn}:5432/${var.postgres_database_name}?sslmode=require"
}

resource "azurerm_key_vault" "main" {
  #checkov:skip=CKV_AZURE_42:Purge protection is intentionally disabled so the disposable lab can be fully recreated after teardown; soft delete remains enabled.
  #checkov:skip=CKV_AZURE_109:Firewall rules would block GitHub-hosted Terraform runners and Container Apps secret resolution in this small public-control-plane design.
  #checkov:skip=CKV_AZURE_110:Purge protection is intentionally disabled to support complete lab teardown; enable it for a long-lived production vault.
  #checkov:skip=CKV_AZURE_189:A private endpoint requires more network/DNS plumbing and a private CI runner; access remains restricted by Entra RBAC.
  #checkov:skip=CKV2_AZURE_32:A private endpoint is deliberately omitted so GitHub-hosted Terraform and Container Apps secret resolution remain operable.
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  soft_delete_retention_days    = 7
  purge_protection_enabled      = false
  public_network_access_enabled = true
  tags                          = var.tags
}

resource "azurerm_role_assignment" "deployer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.deployment_principal_object_id
}

resource "azurerm_role_assignment" "app" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.app_identity_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_key_vault_secret" "postgres_password" {
  #checkov:skip=CKV_AZURE_41:Rotation is an explicit operational action because an automatic expiry would break database access without coordinated rotation.
  name         = "postgres-admin-password"
  value        = var.postgres_admin_password
  key_vault_id = azurerm_key_vault.main.id
  content_type = "password"

  depends_on = [azurerm_role_assignment.deployer]
}

resource "azurerm_key_vault_secret" "database_url" {
  #checkov:skip=CKV_AZURE_41:Rotation is coupled to the PostgreSQL password and must be coordinated rather than expiring silently.
  name         = "database-url"
  value        = local.database_url
  key_vault_id = azurerm_key_vault.main.id
  content_type = "database-connection-string"

  depends_on = [azurerm_role_assignment.deployer]
}

resource "azurerm_key_vault_secret" "jwt_secret" {
  #checkov:skip=CKV_AZURE_41:JWT rotation must overlap signing keys to avoid invalidating every active session; it is intentionally operator-managed.
  name         = "jwt-secret"
  value        = var.jwt_secret
  key_vault_id = azurerm_key_vault.main.id
  content_type = "jwt-signing-key"

  depends_on = [azurerm_role_assignment.deployer]
}

resource "azurerm_key_vault_secret" "application_insights" {
  #checkov:skip=CKV_AZURE_41:The connection string lifecycle is owned by Application Insights and is replaced with that resource rather than expiring independently.
  name         = "application-insights-connection-string"
  value        = var.application_insights_connection_string
  key_vault_id = azurerm_key_vault.main.id
  content_type = "application-insights-connection-string"

  depends_on = [azurerm_role_assignment.deployer]
}

resource "azurerm_monitor_diagnostic_setting" "main" {
  name                       = "send-to-log-analytics"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "audit"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
