locals {
  events  = templatefile("${path.module}/queries/events.kql", { app_name = "${var.name_prefix}-app" })
  details = templatefile("${path.module}/queries/details.kql", { app_name = "${var.name_prefix}-app" })
  commerce_rules = {
    auth_attack                = { display_name = "SOC - Repeated failed authentication", query_file = "auth-attack", severity = "Medium", tactics = ["CredentialAccess"], techniques = ["T1110"], description = "Repeated authentication failures or account lockout, correlated by synthetic run and hashed account." }
    auth_spray                 = { display_name = "SOC - Password spray (repeated failed authentication)", query_file = "auth-spray", severity = "Medium", tactics = ["CredentialAccess"], techniques = ["T1110"], description = "Failures against multiple hashed accounts in a correlated run; source attribution is included only when available." }
    account_registration_burst = { display_name = "SOC - Repeated account registration failures", query_file = "registration", severity = "Low", tactics = [], techniques = [], description = "Repeated rejected registrations. This does not establish unauthorized account creation." }
    admin_activity             = { display_name = "SOC - Administrator account directory access", query_file = "admin-activity", severity = "Low", tactics = ["Discovery"], techniques = ["T1087"], description = "Repeated authenticated administrator reads of the user directory, for investigation of account discovery." }
    api_abuse                  = { display_name = "SOC - Suspicious API request burst", query_file = "api-abuse", severity = "Low", tactics = [], techniques = [], description = "Correlated API request volume, excluding health and metrics endpoints." }
    suspicious_success         = { display_name = "SOC - Successful authentication after failures", query_file = "success-after-failures", severity = "Medium", tactics = ["InitialAccess"], techniques = ["T1078"], description = "A real successful login after at least three failures for the same hashed account and run. This signal does not establish compromise." }
    privilege_probe            = { display_name = "SOC - Privilege boundary probing", query_file = "privilege-probe", severity = "Medium", tactics = ["PrivilegeEscalation"], techniques = ["T1548"], description = "Three distinct authorization-denied requests; repeated HTTP completion events are not double counted." }
    suspicious_request         = { display_name = "SOC - Suspicious request pattern", query_file = "suspicious-request", severity = "Medium", tactics = ["InitialAccess"], techniques = ["T1190"], description = "Suspicious request patterns observed by the application; exploitation is not established." }
    auth_rate_limit            = { display_name = "SOC - Authentication rate limit triggered", query_file = "rate-limit", severity = "Low", tactics = ["CredentialAccess"], techniques = ["T1110"], description = "Application rate-control events, counted once per request." }
  }
  rules = merge({ for key, rule in local.commerce_rules : key => merge(rule, { query = "${local.events}\n${file("${path.module}/queries/${rule.query_file}.kql")}\n${local.details}", enabled = true }) }, {
    cloud_change = {
      display_name = "SOC - Cloud administrative change"
      description  = "Awaiting an approved AzureActivity export to this workspace."
      query        = "AzureActivity | where TimeGenerated > ago(15m) | where ActivityStatusValue =~ 'Success' | where OperationNameValue has_any ('write', 'delete', 'action')"
      severity     = "Low"
      tactics      = ["Persistence"]
      techniques   = ["T1098"]
      enabled      = false
    }
    telemetry_gap = {
      display_name = "SOC - Commerce telemetry gap"
      description  = "Disabled for an on-demand Container App: scale-to-zero is expected and is not a high-severity security event."
      query        = "let lastEvent = toscalar(ContainerAppConsoleLogs_CL | summarize max(TimeGenerated)); print LastEvent=lastEvent | where LastEvent < ago(15m)"
      severity     = "Low"
      tactics      = ["DefenseEvasion"]
      techniques   = ["T1562"]
      enabled      = false
    }
  })
}

resource "azurerm_sentinel_alert_rule_scheduled" "rule" {
  for_each                   = { for key, rule in local.rules : key => rule if var.enable }
  name                       = "${var.name_prefix}-${each.key}"
  display_name               = each.value.display_name
  description                = each.value.description
  log_analytics_workspace_id = var.log_analytics_workspace_id
  query                      = each.value.query
  severity                   = each.value.severity
  enabled                    = each.value.enabled
  query_frequency            = "PT5M"
  query_period               = "PT15M"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  suppression_enabled        = !contains(keys(local.commerce_rules), each.key)
  suppression_duration       = "PT1H"
  tactics                    = each.value.tactics
  techniques                 = each.value.techniques
  custom_details = contains(keys(local.commerce_rules), each.key) ? {
    ScenarioId       = "SimulationId"
    FirstActivityUtc = "FirstActivityUtc"
    LastActivityUtc  = "LastActivityUtc"
    Asset            = "Asset"
    AccountHashes    = "AccountHashes"
  } : {}

  dynamic "event_grouping" {
    for_each = contains(keys(local.commerce_rules), each.key) ? [1] : []
    content { aggregation_method = "AlertPerResult" }
  }

  dynamic "incident" {
    for_each = contains(keys(local.commerce_rules), each.key) ? [1] : []
    content {
      create_incident_enabled = true
      grouping {
        enabled                 = true
        entity_matching_method  = "Selected"
        by_custom_details       = ["ScenarioId"]
        by_alert_details        = ["DisplayName"]
        lookback_duration       = "PT5H"
        reopen_closed_incidents = false
      }
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "sentinel_health" {
  count                      = var.enable ? 1 : 0
  name                       = "${var.name_prefix}-sentinel-health"
  target_resource_id         = "${var.log_analytics_workspace_id}/providers/Microsoft.SecurityInsights/settings/SentinelHealth"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "Analytics"
  }

  enabled_log {
    category = "Automation"
  }
}
