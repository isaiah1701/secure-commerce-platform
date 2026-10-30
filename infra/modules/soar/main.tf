data "azurerm_managed_api" "sentinel" {
  name     = "azuresentinel"
  location = var.location
}

locals {
  # These secrets are provisioned out-of-band so their values never enter
  # Terraform state. The Logic App retrieves them at runtime via managed
  # identity; only their stable Key Vault names are needed here.
  glpi_api_username_secret_name = "soc-glpi-api-username"
  glpi_api_password_secret_name = "soc-glpi-api-password"
  glpi_app_token_secret_name    = "soc-glpi-app-token"
}

resource "azurerm_api_connection" "sentinel" {
  name                = "${var.name_prefix}-sentinel-connection"
  resource_group_name = var.resource_group_name
  managed_api_id      = data.azurerm_managed_api.sentinel.id
  display_name        = "${var.name_prefix} Microsoft Sentinel"
  parameter_values    = {}

  lifecycle {
    ignore_changes = [parameter_values]
  }

  tags = var.tags
}

resource "azurerm_logic_app_workflow" "main" {
  name                = "${var.name_prefix}-soc-glpi-playbook"
  location            = var.location
  resource_group_name = var.resource_group_name
  enabled             = true
  tags                = merge(var.tags, { Workload = "sentinel-glpi-soar" })

  identity {
    type = "SystemAssigned"
  }

  workflow_parameters = {
    "$connections" = jsonencode({
      type         = "Object"
      defaultValue = {}
    })
  }

  parameters = {
    "$connections" = jsonencode({
      azuresentinel = {
        connectionId   = azurerm_api_connection.sentinel.id
        connectionName = azurerm_api_connection.sentinel.name
        connectionProperties = {
          authentication = { type = "ManagedServiceIdentity" }
        }
        id = data.azurerm_managed_api.sentinel.id
      }
    })
  }
}

resource "azurerm_logic_app_trigger_custom" "sentinel_incident" {
  name         = "Microsoft_Sentinel_incident"
  logic_app_id = azurerm_logic_app_workflow.main.id

  body = jsonencode({
    type = "ApiConnectionWebhook"
    inputs = {
      host = {
        connection = {
          name = "@parameters('$connections')['azuresentinel']['connectionId']"
        }
      }
      body = { callback_url = "@{listCallbackUrl()}" }
      path = "/incident-creation"
    }
  })
}

resource "azurerm_logic_app_action_custom" "get_glpi_username" {
  name         = "Get_GLPI_API_Username"
  logic_app_id = azurerm_logic_app_workflow.main.id

  body = jsonencode({
    type = "Http"
    inputs = {
      method = "GET"
      uri    = "https://${var.key_vault_name}.vault.azure.net/secrets/${local.glpi_api_username_secret_name}?api-version=7.4"
      authentication = {
        type     = "ManagedServiceIdentity"
        audience = "https://vault.azure.net"
      }
    }
    runtimeConfiguration = { secureData = { properties = ["inputs", "outputs"] } }
    runAfter             = {}
  })

  depends_on = [azurerm_logic_app_trigger_custom.sentinel_incident]
}

resource "azurerm_logic_app_action_custom" "get_glpi_password" {
  name         = "Get_GLPI_API_Password"
  logic_app_id = azurerm_logic_app_workflow.main.id

  body = jsonencode({
    type = "Http"
    inputs = {
      method = "GET"
      uri    = "https://${var.key_vault_name}.vault.azure.net/secrets/${local.glpi_api_password_secret_name}?api-version=7.4"
      authentication = {
        type     = "ManagedServiceIdentity"
        audience = "https://vault.azure.net"
      }
    }
    runtimeConfiguration = { secureData = { properties = ["inputs", "outputs"] } }
    runAfter             = {}
  })

  depends_on = [azurerm_logic_app_trigger_custom.sentinel_incident]
}

resource "azurerm_logic_app_action_custom" "get_glpi_app_token" {
  name         = "Get_GLPI_App_Token"
  logic_app_id = azurerm_logic_app_workflow.main.id

  body = jsonencode({
    type = "Http"
    inputs = {
      method = "GET"
      uri    = "https://${var.key_vault_name}.vault.azure.net/secrets/${local.glpi_app_token_secret_name}?api-version=7.4"
      authentication = {
        type     = "ManagedServiceIdentity"
        audience = "https://vault.azure.net"
      }
    }
    runtimeConfiguration = { secureData = { properties = ["inputs", "outputs"] } }
    runAfter             = {}
  })

  depends_on = [azurerm_logic_app_trigger_custom.sentinel_incident]
}

resource "azurerm_logic_app_action_custom" "init_glpi_session" {
  name         = "Init_GLPI_Session"
  logic_app_id = azurerm_logic_app_workflow.main.id

  body = jsonencode({
    type = "Http"
    inputs = {
      method = "GET"
      uri    = "${trim(var.glpi_api_url, "/")}/apirest.php/initSession/"
      headers = {
        "Content-Type" = "application/json"
        "App-Token"    = "@{body('Get_GLPI_App_Token')?['value']}"
        Authorization  = "@{concat('Basic ', base64(concat(body('Get_GLPI_API_Username')?['value'], ':', body('Get_GLPI_API_Password')?['value'])))}"
      }
      retryPolicy = { type = "exponential", count = 3, interval = "PT10S" }
    }
    runtimeConfiguration = { secureData = { properties = ["inputs", "outputs"] } }
    runAfter = {
      Get_GLPI_API_Username = ["Succeeded"]
      Get_GLPI_API_Password = ["Succeeded"]
      Get_GLPI_App_Token    = ["Succeeded"]
    }
  })

  depends_on = [
    azurerm_logic_app_action_custom.get_glpi_username,
    azurerm_logic_app_action_custom.get_glpi_password,
    azurerm_logic_app_action_custom.get_glpi_app_token,
  ]
}

resource "azurerm_logic_app_action_custom" "query_log_analytics" {
  name         = "Query_Commerce_Evidence"
  logic_app_id = azurerm_logic_app_workflow.main.id

  body = jsonencode({
    type = "Http"
    inputs = {
      method  = "POST"
      uri     = "https://api.loganalytics.azure.com/v1/workspaces/${var.workspace_customer_id}/query"
      headers = { "Content-Type" = "application/json" }
      authentication = {
        type     = "ManagedServiceIdentity"
        audience = "https://api.loganalytics.io"
      }
      body = {
        query = "let incident_start=datetime('@{coalesce(triggerBody()?['object']?['properties']?['firstActivityTimeUtc'], triggerBody()?['object']?['properties']?['createdTimeUtc'])}'); let incident_end=datetime('@{coalesce(triggerBody()?['object']?['properties']?['lastActivityTimeUtc'], triggerBody()?['object']?['properties']?['createdTimeUtc'])}'); ContainerAppConsoleLogs_CL | where TimeGenerated between (incident_start - 15m .. incident_end + 15m) | extend payload=parse_json(Log_s) | where isnotempty(tostring(payload.event_type)) | project TimeGenerated, event_type=tostring(payload.event_type), simulation_id=tostring(payload.simulation_id), source_ip=tostring(payload.source_ip), request_id=tostring(payload.request_id), path=tostring(payload.path), status_code=toint(payload.status_code) | summarize MatchingEvents=count(), EventTypes=make_set(event_type), StatusCodes=make_set(status_code), SourceIPs=make_set(source_ip), Endpoints=make_set(path), RequestIds=make_set(request_id), SimulationIds=make_set(simulation_id) by bin(TimeGenerated, 1m) | order by TimeGenerated asc"
      }
    }
    runAfter = { Init_GLPI_Session = ["Succeeded"] }
  })

  depends_on = [azurerm_logic_app_action_custom.init_glpi_session]
}

resource "azurerm_logic_app_action_custom" "search_existing_ticket" {
  name         = "Search_Existing_GLPI_Ticket"
  logic_app_id = azurerm_logic_app_workflow.main.id

  body = jsonencode({
    type = "Http"
    inputs = {
      method = "GET"
      uri    = "${trim(var.glpi_api_url, "/")}/apirest.php/search/Ticket/"
      headers = {
        "Content-Type"  = "application/json"
        "App-Token"     = "@{body('Get_GLPI_App_Token')?['value']}"
        "Session-Token" = "@{body('Init_GLPI_Session')?['session_token']}"
      }
      queries = {
        "criteria[0][field]"      = "1"
        "criteria[0][searchtype]" = "contains"
        "criteria[0][value]"      = "@{string(coalesce(triggerBody()?['object']?['properties']?['incidentId'], last(split(triggerBody()?['object']?['properties']?['incidentUrl'], '/'))))}"
        "criteria[1][field]"      = "1"
        "criteria[1][searchtype]" = "contains"
        "criteria[1][value]"      = "@{string(triggerBody()?['object']?['properties']?['incidentNumber'])}"
        "criteria[1][link]"       = "OR"
      }
    }
    runAfter = { Query_Commerce_Evidence = ["Succeeded"] }
  })

  depends_on = [azurerm_logic_app_action_custom.query_log_analytics]
}

resource "azurerm_logic_app_action_custom" "create_if_missing" {
  name         = "Create_GLPI_Ticket_If_Missing"
  logic_app_id = azurerm_logic_app_workflow.main.id

  body = jsonencode({
    type = "If"
    expression = {
      equals = ["@body('Search_Existing_GLPI_Ticket')?['totalcount']", 0]
    }
    actions = {
      Create_GLPI_Ticket = {
        type = "Http"
        inputs = {
          method = "POST"
          uri    = "${trim(var.glpi_api_url, "/")}/apirest.php/Ticket/"
          headers = {
            "Content-Type"  = "application/json"
            "App-Token"     = "@{body('Get_GLPI_App_Token')?['value']}"
            "Session-Token" = "@{body('Init_GLPI_Session')?['session_token']}"
          }
          body = {
            input = {
              name              = "[SOC LAB] Sentinel incident @{triggerBody()?['object']?['properties']?['incidentNumber']} - @{triggerBody()?['object']?['properties']?['title']}"
              content           = <<-EOT
                SOC INVESTIGATION CASE

                INCIDENT BRIEFING
                The commerce application provides authentication, customer accounts, product administration and order processing. Sentinel detected this activity; the alert is not proof of an attack or successful access.

                INCIDENT DETAILS
                - Sentinel incident number: @{triggerBody()?['object']?['properties']?['incidentNumber']}
                - Sentinel incident ID: @{coalesce(triggerBody()?['object']?['properties']?['incidentId'], last(split(triggerBody()?['object']?['properties']?['incidentUrl'], '/')))}
                - Sentinel incident URL: @{triggerBody()?['object']?['properties']?['incidentUrl']}
                - Detection rule: @{triggerBody()?['object']?['properties']?['title']}
                - Severity: @{triggerBody()?['object']?['properties']?['severity']}
                - First observed UTC: @{coalesce(triggerBody()?['object']?['properties']?['firstActivityTimeUtc'], triggerBody()?['object']?['properties']?['createdTimeUtc'])}
                - Last observed UTC: @{coalesce(triggerBody()?['object']?['properties']?['lastActivityTimeUtc'], triggerBody()?['object']?['properties']?['createdTimeUtc'])}
                - Evidence collected UTC: @{utcNow()}

                BUSINESS IMPACT AND SECURITY RELEVANCE
                If genuine, this activity could affect customer sign-in, account confidentiality, administrative product changes or order integrity. Do not claim compromise, customer impact or data exposure until verified.

                EVIDENCE SNAPSHOT
                @{string(body('Query_Commerce_Evidence'))}
                Evidence limitation: only fields present in ContainerAppConsoleLogs_CL and the Sentinel trigger are available. Record missing identities or impact as unknown.

                SCENARIO-SPECIFIC PLAYBOOK
                1. Authentication failures and lockout: count attempts, identify accounts and sources, verify lockout and success, and distinguish brute force, password spraying or benign activity.
                2. Authentication rate limiting: identify endpoint, volume, duration, HTTP 429 count, accepted requests, source concentration and legitimate impact.
                3. Privilege boundary probing: identify restricted endpoints and identity, count HTTP 403 responses, verify permissions and privileged success, and assess authorization.
                4. Suspicious API activity: identify flagged paths and safe request characteristics, source, responses, probing versus exploitation, validation and related activity. Do not copy executable payloads.
                5. Correlated suspicious activity: reconstruct the sequence and correlate source, identity, request and simulation IDs; check failures followed by success or privilege probing.

                REPRODUCIBLE KQL - EXACT MATCHING WINDOW
                let incident_start=datetime(@{coalesce(triggerBody()?['object']?['properties']?['firstActivityTimeUtc'], triggerBody()?['object']?['properties']?['createdTimeUtc'])});
                let incident_end=datetime(@{coalesce(triggerBody()?['object']?['properties']?['lastActivityTimeUtc'], triggerBody()?['object']?['properties']?['createdTimeUtc'])});
                ContainerAppConsoleLogs_CL
                | where TimeGenerated between (incident_start .. incident_end)
                | extend payload=parse_json(Log_s)
                | project TimeGenerated, event_type=tostring(payload.event_type), simulation_id=tostring(payload.simulation_id), source_ip=tostring(payload.source_ip), request_id=tostring(payload.request_id), path=tostring(payload.path), status_code=toint(payload.status_code)
                | order by TimeGenerated asc

                REPRODUCIBLE KQL - TIMELINE, CONTEXT AND CORRELATION
                let incident_start=datetime(@{coalesce(triggerBody()?['object']?['properties']?['firstActivityTimeUtc'], triggerBody()?['object']?['properties']?['createdTimeUtc'])}); let incident_end=datetime(@{coalesce(triggerBody()?['object']?['properties']?['lastActivityTimeUtc'], triggerBody()?['object']?['properties']?['createdTimeUtc'])});
                ContainerAppConsoleLogs_CL | where TimeGenerated between (incident_start - 15m .. incident_end + 15m) | extend payload=parse_json(Log_s) | project TimeGenerated, event_type=tostring(payload.event_type), simulation_id=tostring(payload.simulation_id), source_ip=tostring(payload.source_ip), request_id=tostring(payload.request_id), path=tostring(payload.path), status_code=toint(payload.status_code) | order by TimeGenerated asc

                REPRODUCIBLE KQL - WIDER CONTEXT
                let incident_start=datetime(@{coalesce(triggerBody()?['object']?['properties']?['firstActivityTimeUtc'], triggerBody()?['object']?['properties']?['createdTimeUtc'])}); let incident_end=datetime(@{coalesce(triggerBody()?['object']?['properties']?['lastActivityTimeUtc'], triggerBody()?['object']?['properties']?['createdTimeUtc'])});
                ContainerAppConsoleLogs_CL | where TimeGenerated between (incident_start - 60m .. incident_end + 60m) | extend payload=parse_json(Log_s) | summarize Events=count(), EventTypes=make_set(tostring(payload.event_type)), StatusCodes=make_set(tostring(payload.status_code)), Sources=make_set(tostring(payload.source_ip)), Endpoints=make_set(tostring(payload.path)) by bin(TimeGenerated, 5m) | order by TimeGenerated asc

                REPRODUCIBLE KQL - SCENARIO OUTCOME
                let incident_start=datetime(@{coalesce(triggerBody()?['object']?['properties']?['firstActivityTimeUtc'], triggerBody()?['object']?['properties']?['createdTimeUtc'])}); let incident_end=datetime(@{coalesce(triggerBody()?['object']?['properties']?['lastActivityTimeUtc'], triggerBody()?['object']?['properties']?['createdTimeUtc'])});
                ContainerAppConsoleLogs_CL | where TimeGenerated between (incident_start - 15m .. incident_end + 15m) | extend payload=parse_json(Log_s) | summarize Events=count(), StatusCodes=make_set(toint(payload.status_code)), Paths=make_set(tostring(payload.path)), EventTypes=make_set(tostring(payload.event_type)) by tostring(payload.simulation_id), tostring(payload.source_ip) | order by Events desc

                REPRODUCIBLE KQL - CORRELATION
                let incident_start=datetime(@{coalesce(triggerBody()?['object']?['properties']?['firstActivityTimeUtc'], triggerBody()?['object']?['properties']?['createdTimeUtc'])}); let incident_end=datetime(@{coalesce(triggerBody()?['object']?['properties']?['lastActivityTimeUtc'], triggerBody()?['object']?['properties']?['createdTimeUtc'])});
                ContainerAppConsoleLogs_CL | where TimeGenerated between (incident_start - 60m .. incident_end + 60m) | extend payload=parse_json(Log_s) | project TimeGenerated, event_type=tostring(payload.event_type), simulation_id=tostring(payload.simulation_id), request_id=tostring(payload.request_id), source_ip=tostring(payload.source_ip), path=tostring(payload.path), status_code=toint(payload.status_code) | where isnotempty(simulation_id) or isnotempty(request_id) | order by TimeGenerated asc

                ANALYST ACTIONS
                Review Sentinel; reproduce the exact evidence; build the timeline; identify affected resources or unknowns; compare successful, blocked, failed and rate-limited activity; review related events; select and justify a Sentinel-supported classification; attach privacy-safe evidence; and document findings in GLPI follow-ups.
                Native-task limitation: the soc-automation GLPI profile can create tickets but currently receives ERROR_RIGHT_MISSING for TicketTask creation. These actions are therefore intentionally presented as analyst-owned steps and follow-up notes, not auto-completed tasks. Grant the profile task permission only after an authorised GLPI administrator approves it.

                AUTHORISATION AND ESCALATION
                Tier 1 may review Sentinel, run read-only KQL, inspect telemetry, document observations, attach evidence, recommend containment and escalate. Tier 1 may not disable accounts, block IPs, modify production controls or detections, delete evidence or execute destructive response. Escalate unauthorized access, successful unauthorized privileged operations, data exposure, failed controls, multiple affected identities/services, serious uncertainty or ongoing threats. Escalation owner/group is unverified and must be recorded as an operational gap.

                DEFINITION OF DONE
                Verify alert and rule; reproduce evidence; document timeline and scope or unknowns; assess successful and failed activity; explain controls; choose and justify classification; attach evidence; escalate or explicitly rule out; document recommendations, uncertainties and final findings; reconcile GLPI and Sentinel by an authorized analyst. Automation success is not closure.

                ANALYST FINDINGS
                Classification:
                Scope:
                Timeline:
                Control assessment:
                Impact:
                Confidence:
                Escalation decision:
                Recommended actions:
                Outstanding uncertainties:
                Final conclusion:
              EOT
              itilcategories_id = 0
              priority          = 3
              users_id_recipient = 7
            }
          }
          retryPolicy = { type = "exponential", count = 3, interval = "PT10S" }
        }
        runAfter = {}
      }
    }
    else     = {}
    runAfter = { Search_Existing_GLPI_Ticket = ["Succeeded"] }
  })

  depends_on = [azurerm_logic_app_action_custom.search_existing_ticket]
}

resource "azurerm_role_assignment" "key_vault_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_logic_app_workflow.main.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "sentinel_responder" {
  scope                = var.workspace_id
  role_definition_name = "Microsoft Sentinel Responder"
  principal_id         = azurerm_logic_app_workflow.main.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "sentinel_automation_contributor" {
  scope                = var.resource_group_id
  role_definition_name = "Microsoft Sentinel Automation Contributor"
  principal_id         = var.sentinel_service_principal_object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "log_analytics_reader" {
  scope                = var.workspace_id
  role_definition_name = "Log Analytics Reader"
  principal_id         = azurerm_logic_app_workflow.main.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_sentinel_automation_rule" "glpi" {
  name                       = uuidv5("url", "${var.name_prefix}-sentinel-to-glpi")
  log_analytics_workspace_id = var.workspace_id
  display_name               = "SOC - Create GLPI investigation ticket"
  order                      = 100
  enabled                    = true
  triggers_on                = "Incidents"
  triggers_when              = "Created"

  action_playbook {
    logic_app_id = azurerm_logic_app_workflow.main.id
    order        = 1
    tenant_id    = data.azurerm_client_config.current.tenant_id
  }
}

data "azurerm_client_config" "current" {}
