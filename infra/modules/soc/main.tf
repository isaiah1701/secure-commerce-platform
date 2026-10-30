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
    suspicious_success = {
      display_name = "SOC - Successful authentication after failures"
      description  = "Detects a success from a source that recently generated repeated failures."
      query        = <<-KQL
        let failures = ContainerAppConsoleLogs_CL
          | where TimeGenerated > ago(15m)
          | where column_ifexists("Log_s", "") has_any ("401", "login failed", "authentication failed")
          | summarize FailureCount=count() by SourceIP=column_ifexists("ClientIP_s", "unknown");
        ContainerAppConsoleLogs_CL
        | where TimeGenerated > ago(10m)
        | where column_ifexists("Log_s", "") has_any ("200", "login successful", "authenticated")
        | extend SourceIP=column_ifexists("ClientIP_s", "unknown")
        | join kind=inner (failures) on SourceIP
        | where FailureCount >= 5
      KQL
      severity     = "High"
      tactics      = ["CredentialAccess"]
      techniques   = ["T1078"]
    }
    privilege_probe = {
      display_name = "SOC - Privilege boundary probing"
      description  = "Detects repeated forbidden responses against protected commerce endpoints."
      query        = <<-KQL
        ContainerAppConsoleLogs_CL
        | where TimeGenerated > ago(10m)
        | where column_ifexists("Log_s", "") has_any ("403", "forbidden", "permission denied", "admin")
        | summarize ProbeCount=count(), FirstSeen=min(TimeGenerated), LastSeen=max(TimeGenerated) by SourceIP=column_ifexists("ClientIP_s", "unknown")
        | where ProbeCount >= 10
      KQL
      severity     = "Medium"
      tactics      = ["PrivilegeEscalation", "Discovery"]
      techniques   = ["T1548"]
    }
    cloud_change = {
      display_name = "SOC - Cloud administrative change"
      description  = "Detects successful administrative changes delivered to the workspace."
      query        = <<-KQL
        AzureActivity
        | where TimeGenerated > ago(10m)
        | where ActivityStatusValue =~ "Success"
        | where OperationNameValue has_any ("write", "delete", "action")
        | summarize ChangeCount=count(), FirstSeen=min(TimeGenerated), LastSeen=max(TimeGenerated) by Caller, ResourceGroup
        | where ChangeCount >= 1
      KQL
      severity     = "Low"
      tactics      = ["Persistence"]
      techniques   = ["T1098"]
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
