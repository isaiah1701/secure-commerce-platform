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
        query = "let incident_start=datetime('@{coalesce(triggerBody()?['object']?['properties']?['firstActivityTimeUtc'], triggerBody()?['object']?['properties']?['createdTimeUtc'])}'); let incident_end=datetime('@{coalesce(triggerBody()?['object']?['properties']?['lastActivityTimeUtc'], triggerBody()?['object']?['properties']?['createdTimeUtc'])}'); let detection='@{toLower(string(triggerBody()?['object']?['properties']?['title']))}'; ContainerAppConsoleLogs_CL | where TimeGenerated between (incident_start - 15m .. incident_end + 15m) | extend payload=parse_json(Log_s) | extend event_type=tostring(payload.event_type), status_code=toint(payload.status_code), path=tostring(payload.path) | where isnotempty(event_type) | where case(detection has 'rate', event_type == 'RATE_LIMIT_EXCEEDED' or (event_type == 'HTTP_REQUEST' and status_code == 429), detection has 'privilege', event_type == 'AUTH_FORBIDDEN' or status_code == 403, detection has 'failed', event_type == 'AUTH_LOGIN_FAILURE' or event_type == 'AUTH_ACCOUNT_LOCKED', detection has 'suspicious', event_type == 'SUSPICIOUS_REQUEST' or (event_type == 'HTTP_REQUEST' and path !in ('/health', '/ready')), true) | project TimeGenerated, event_type, simulation_id=tostring(payload.simulation_id), source_ip=tostring(payload.source_ip), request_id=tostring(payload.request_id), path, status_code | summarize MatchingEvents=count(), EventTypes=make_set(event_type), StatusCodes=make_set(status_code), SourceIPs=make_set(source_ip), Endpoints=make_set(path), RequestIds=make_set(request_id), SimulationIds=make_set(simulation_id) by bin(TimeGenerated, 1m) | order by TimeGenerated asc"
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
                SOC CASE — REVIEW IN MICROSOFT SENTINEL

                What happened: Sentinel detected activity involving the online commerce application. This can affect customer sign-in, customer accounts, product administration, or orders, but the alert does not prove malicious activity or successful access. Confirm the facts in Sentinel and Log Analytics.

                INCIDENT
                - Sentinel incident: @{triggerBody()?['object']?['properties']?['incidentNumber']}
                - Severity: @{triggerBody()?['object']?['properties']?['severity']}
                - Detection rule: @{triggerBody()?['object']?['properties']?['title']}
                - UTC window: @{coalesce(triggerBody()?['object']?['properties']?['firstActivityTimeUtc'], triggerBody()?['object']?['properties']?['createdTimeUtc'])} to @{coalesce(triggerBody()?['object']?['properties']?['lastActivityTimeUtc'], triggerBody()?['object']?['properties']?['createdTimeUtc'])}
                - Sentinel: @{triggerBody()?['object']?['properties']?['incidentUrl']}
                - Log Analytics workspace: https://portal.azure.com/#view/Microsoft_Azure_Monitoring_Logs/LogsBlade/resourceId/%2Fsubscriptions%2F43adc2c2-0fd5-4474-aa8a-9f32f541e4b7%2FresourceGroups%2Fsecure-commerce-dev-rg%2Fproviders%2FMicrosoft.OperationalInsights%2Fworkspaces%2Fsecure-commerce-dev-law

                OBJECTIVE
                @{if(contains(toLower(string(triggerBody()?['object']?['properties']?['title'])),'rate'), 'Determine whether authentication throttling worked, how many requests were blocked, and whether legitimate traffic was affected.', if(contains(toLower(string(triggerBody()?['object']?['properties']?['title'])),'privilege'), 'Determine whether authorization blocked the restricted operation and whether any privileged action succeeded.', if(contains(toLower(string(triggerBody()?['object']?['properties']?['title'])),'failed'), 'Determine the targeted identity, source pattern, lockout behavior, and whether authentication later succeeded.', if(contains(toLower(string(triggerBody()?['object']?['properties']?['title'])),'suspicious'), 'Determine whether the request pattern was probing or exploitation and whether application controls worked.', 'Reconstruct the related event sequence and decide whether the combined activity changes severity.'))))}

                INVESTIGATION — MAXIMUM FIVE STEPS
                1. Open the Sentinel link; verify the incident, rule, severity, alert entities, and UTC window.
                2. In the linked Log Analytics workspace, reproduce the incident-window query from the [SOC runbook](https://github.com/isaiah1701/secure-commerce-platform/blob/main/docs/soc/runbook.md). Use the incident timestamps, not relative ago() windows.
                3. Build a timeline and record affected resources, source addresses, request IDs, simulation IDs, endpoints, and successful versus blocked outcomes.
                4. Review related activity before and after the window; distinguish confirmed facts from hypotheses and unknowns.
                5. Record the classification, impact assessment, confidence, recommended action, and escalation decision in GLPI.

                DEFINITION OF DONE
                Evidence and rule verified; timeline documented; affected resources identified or marked unknown; successful and failed activity assessed; classification and potential impact justified; supporting evidence linked; escalation completed or explicitly ruled out; final findings recorded. Leave this ticket open until an authorized analyst completes the review. Automation never closes the case.
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
