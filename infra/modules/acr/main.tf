resource "azurerm_container_registry" "main" {
  #checkov:skip=CKV_AZURE_139:Private endpoints require Premium ACR; this small lab uses authenticated RBAC access over the public service endpoint.
  #checkov:skip=CKV_AZURE_163:Microsoft Defender registry scanning is subscription-level; the delivery workflow blocks HIGH/CRITICAL Trivy findings before push.
  #checkov:skip=CKV_AZURE_164:ACR content trust is not available on the selected Basic tier; immutable SHA tags and Trivy are used instead.
  #checkov:skip=CKV_AZURE_165:The app is intentionally single-region, so geo-replication would add cost without a matching failover deployment.
  #checkov:skip=CKV_AZURE_166:Quarantine is a Premium feature; CI scans before push and deployment uses a commit-SHA tag.
  #checkov:skip=CKV_AZURE_167:Untagged-manifest retention is not available on Basic ACR; this small lab uses immutable SHA tags and should be pruned during maintenance.
  #checkov:skip=CKV_AZURE_233:Zone redundancy is a Premium feature and is outside this cost-controlled single-region lab.
  #checkov:skip=CKV_AZURE_237:Dedicated data endpoints are a Premium feature and are unnecessary with the intentionally public authenticated endpoint.
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = "Basic"
  admin_enabled                 = false
  anonymous_pull_enabled        = false
  public_network_access_enabled = true
  tags                          = var.tags
}

resource "azurerm_user_assigned_identity" "app" {
  name                = var.identity_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "push" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPush"
  principal_id         = var.deployment_principal_object_id
}

resource "azurerm_monitor_diagnostic_setting" "main" {
  name                       = "send-to-log-analytics"
  target_resource_id         = azurerm_container_registry.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
