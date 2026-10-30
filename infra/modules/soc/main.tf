locals {
  rules = {
    auth_attack = {
      display_name = "SOC - Repeated failed authentication"
      description  = "Detects a bounded burst of failed authentication events from one source."
      query        = <<-KQL
        ContainerAppConsoleLogs_CL
        | where TimeGenerated > ago(10m)
        | where column_ifexists("Log_s", "") has_any ("401", "invalid credentials", "login failed", "authentication failed")
        | summarize FailureCount=count(), FirstSeen=min(TimeGenerated), LastSeen=max(TimeGenerated) by SourceIP=column_ifexists("ClientIP_s", "unknown")
        | where FailureCount >= 8
      KQL
      severity     = "Medium"
      tactics      = ["CredentialAccess"]
      techniques   = ["T1110"]
    }
    api_abuse = {
      display_name = "SOC - Suspicious API request burst"
      description  = "Detects abnormal request volume for one source in the commerce logs."
      query        = <<-KQL
        ContainerAppConsoleLogs_CL
        | where TimeGenerated > ago(10m)
        | summarize RequestCount=count(), FirstSeen=min(TimeGenerated), LastSeen=max(TimeGenerated) by SourceIP=column_ifexists("ClientIP_s", "unknown"), App=column_ifexists("ContainerAppName_s", "unknown")
        | where RequestCount >= 200
      KQL
      severity     = "Low"
      tactics      = ["Discovery"]
      techniques   = ["T1046"]
    }
    telemetry_gap = {
      display_name = "SOC - Commerce telemetry gap"
      description  = "Detects when expected commerce console telemetry stops arriving."
      query        = <<-KQL
        let lastEvent = toscalar(ContainerAppConsoleLogs_CL | summarize max(TimeGenerated));
        print LastEvent=lastEvent
        | where LastEvent < ago(15m)
      KQL
      severity     = "High"
      tactics      = ["DefenseEvasion"]
      techniques   = ["T1562"]
    }
  }
}

resource "azurerm_sentinel_alert_rule_scheduled" "rule" {
  for_each                   = var.enable ? local.rules : {}
  name                       = "${var.name_prefix}-${each.key}"
  display_name               = each.value.display_name
  description                = each.value.description
  log_analytics_workspace_id = var.log_analytics_workspace_id
  query                      = each.value.query
  severity                   = each.value.severity
  enabled                    = true
  query_frequency            = "PT5M"
  query_period               = "PT10M"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  suppression_enabled        = true
  suppression_duration       = "PT1H"
  tactics                    = each.value.tactics
  techniques                 = each.value.techniques
}
