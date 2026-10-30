locals {
  rules = {
    auth_attack = {
      display_name = "SOC - Repeated failed authentication"
      description  = "Detects a bounded burst of failed authentication events from one source."
      query        = <<-KQL
        ContainerAppConsoleLogs_CL
        | where TimeGenerated > ago(10m)
        | extend payload=parse_json(Log_s), event_type=tostring(payload.event_type), source=tostring(payload.source_ip), simulation_id=tostring(payload.simulation_id)
        | where event_type in ("AUTH_LOGIN_FAILURE", "AUTH_ACCOUNT_LOCKED")
        | summarize FailureCount=countif(event_type == "AUTH_LOGIN_FAILURE"), Locked=countif(event_type == "AUTH_ACCOUNT_LOCKED"), FirstSeen=min(TimeGenerated), LastSeen=max(TimeGenerated), RequestIds=make_set(tostring(payload.request_id), 20) by source, simulation_id
        | where FailureCount >= 5 or Locked >= 1
      KQL
      severity     = "Medium"
      tactics      = ["CredentialAccess"]
      techniques   = ["T1110"]
    }
    auth_spray = {
      display_name = "SOC - Password spraying across accounts"
      description  = "Detects repeated authentication failures against multiple accounts from one source."
      query        = <<-KQL
        ContainerAppConsoleLogs_CL
        | where TimeGenerated > ago(10m)
        | extend payload=parse_json(Log_s)
        | extend event_type=tostring(payload.event_type), source=tostring(payload.source_ip), target=tostring(payload.email_hash), simulation_id=tostring(payload.simulation_id)
        | where event_type == "AUTH_LOGIN_FAILURE" and isnotempty(target)
        | summarize FailureCount=count(), TargetedAccounts=dcount(target), FirstSeen=min(TimeGenerated), LastSeen=max(TimeGenerated), RequestIds=make_set(tostring(payload.request_id), 20) by source, simulation_id
        | where FailureCount >= 5 and TargetedAccounts >= 3
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
        | extend payload=parse_json(Log_s), event_type=tostring(payload.event_type), source=tostring(payload.source_ip), simulation_id=tostring(payload.simulation_id)
        | where event_type == "HTTP_REQUEST"
        | summarize RequestCount=count(), FirstSeen=min(TimeGenerated), LastSeen=max(TimeGenerated), Paths=make_set(tostring(payload.path), 20) by source, simulation_id
        | where RequestCount >= 50
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
          | extend payload=parse_json(Log_s), event_type=tostring(payload.event_type), source=tostring(payload.source_ip), simulation_id=tostring(payload.simulation_id)
          | where event_type == "AUTH_LOGIN_FAILURE"
          | summarize FailureCount=count() by source, simulation_id;
        ContainerAppConsoleLogs_CL
        | where TimeGenerated > ago(10m)
        | extend payload=parse_json(Log_s), event_type=tostring(payload.event_type), source=tostring(payload.source_ip), simulation_id=tostring(payload.simulation_id)
        | where event_type == "AUTH_LOGIN_SUCCESS"
        | join kind=inner (failures) on source, simulation_id
        | where FailureCount >= 5
      KQL
      severity     = "High"
      tactics      = ["DefenseEvasion", "Persistence"]
      techniques   = ["T1078"]
    }
    privilege_probe = {
      display_name = "SOC - Privilege boundary probing"
      description  = "Detects repeated forbidden responses against protected commerce endpoints."
      query        = <<-KQL
        ContainerAppConsoleLogs_CL
        | where TimeGenerated > ago(10m)
        | extend payload=parse_json(Log_s), event_type=tostring(payload.event_type), status=toint(payload.status_code), source=tostring(payload.source_ip), simulation_id=tostring(payload.simulation_id)
        | where event_type == "AUTH_FORBIDDEN" or status == 403
        | summarize ProbeCount=count(), FirstSeen=min(TimeGenerated), LastSeen=max(TimeGenerated), Paths=make_set(tostring(payload.path), 20) by source, simulation_id
        | where ProbeCount >= 3
      KQL
      severity     = "Medium"
      tactics      = ["PrivilegeEscalation", "Discovery"]
      techniques   = ["T1548"]
    }
    suspicious_request = {
      display_name = "SOC - Suspicious request pattern"
      description  = "Detects safe lab requests matching the application's suspicious-pattern telemetry."
      query        = <<-KQL
        ContainerAppConsoleLogs_CL
        | where TimeGenerated > ago(10m)
        | extend payload=parse_json(Log_s), event_type=tostring(payload.event_type), source=tostring(payload.source_ip), simulation_id=tostring(payload.simulation_id)
        | where event_type == "SUSPICIOUS_REQUEST"
        | summarize SuspiciousCount=count(), FirstSeen=min(TimeGenerated), LastSeen=max(TimeGenerated), Paths=make_set(tostring(payload.path), 20), RequestIds=make_set(tostring(payload.request_id), 20) by source, simulation_id
        | where SuspiciousCount >= 1
      KQL
      severity     = "Medium"
      tactics      = ["InitialAccess", "Discovery"]
      techniques   = ["T1190"]
    }
    auth_rate_limit = {
      display_name = "SOC - Authentication rate limit triggered"
      description  = "Detects application authentication requests rejected by the rate limiter."
      query        = <<-KQL
        ContainerAppConsoleLogs_CL
        | where TimeGenerated > ago(10m)
        | extend payload=parse_json(Log_s), event_type=tostring(payload.event_type), status=toint(payload.status_code), source=tostring(payload.source_ip), simulation_id=tostring(payload.simulation_id)
        | where isnotempty(simulation_id) and (event_type == "RATE_LIMIT_EXCEEDED" or (event_type == "HTTP_REQUEST" and status == 429))
        | summarize RateLimitedCount=count(), FirstSeen=min(TimeGenerated), LastSeen=max(TimeGenerated), RequestIds=make_set(tostring(payload.request_id), 20) by source, simulation_id
        | where RateLimitedCount >= 1
      KQL
      severity     = "Medium"
      tactics      = ["CredentialAccess"]
      techniques   = ["T1110"]
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
