data "azurerm_managed_api" "sentinel" {
  name     = "azuresentinel"
  location = var.location
}

resource "azurerm_key_vault_secret" "glpi_api_username" {
  name         = "soc-glpi-api-username"
  value        = var.glpi_api_username
  key_vault_id = var.key_vault_id
  content_type = "GLPI API integration username"
}

resource "azurerm_key_vault_secret" "glpi_api_password" {
  name         = "soc-glpi-api-password"
  value        = var.glpi_api_password
  key_vault_id = var.key_vault_id
  content_type = "GLPI API integration password"
}

resource "azurerm_key_vault_secret" "glpi_app_token" {
  name         = "soc-glpi-app-token"
  value        = var.glpi_app_token
  key_vault_id = var.key_vault_id
  content_type = "GLPI API application token"
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
      value = {
        azuresentinel = {
          connectionId   = azurerm_api_connection.sentinel.id
          connectionName = azurerm_api_connection.sentinel.name
          id             = data.azurerm_managed_api.sentinel.id
          connectionProperties = {
            authentication = { type = "ManagedServiceIdentity" }
          }
        }
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
      uri    = "https://${var.key_vault_name}.vault.azure.net/secrets/${azurerm_key_vault_secret.glpi_api_username.name}?api-version=7.4"
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
      uri    = "https://${var.key_vault_name}.vault.azure.net/secrets/${azurerm_key_vault_secret.glpi_api_password.name}?api-version=7.4"
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
      uri    = "https://${var.key_vault_name}.vault.azure.net/secrets/${azurerm_key_vault_secret.glpi_app_token.name}?api-version=7.4"
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
      uri     = "https://api.loganalytics.io/v1/workspaces/${var.workspace_customer_id}/query"
      headers = { "Content-Type" = "application/json" }
      authentication = {
        type     = "ManagedServiceIdentity"
        audience = "https://api.loganalytics.io"
      }
      body = {
        query = "ContainerAppConsoleLogs_CL | where TimeGenerated > ago(30m) | extend payload=parse_json(Log_s) | project TimeGenerated, event_type=tostring(payload.event_type), simulation_id=tostring(payload.simulation_id), source_ip=tostring(payload.source_ip), request_id=tostring(payload.request_id), path=tostring(payload.path), status_code=toint(payload.status_code) | order by TimeGenerated asc | take 100"
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
        "criteria[0][value]"      = "@{string(triggerBody()?['object']?['properties']?['incidentNumber'])}"
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
              content           = "Controlled lab simulation.\n\nIncident summary\n- Sentinel incident: @{triggerBody()?['object']?['properties']?['incidentNumber']}\n- Severity: @{triggerBody()?['object']?['properties']?['severity']}\n- Created: @{triggerBody()?['object']?['properties']?['createdTimeUtc']}\n- Detection: @{triggerBody()?['object']?['properties']?['title']}\n- Direct URL: @{triggerBody()?['object']?['properties']?['incidentUrl']}\n\nAnalyst objective\nInvestigate the activity, establish scope and timeline, determine whether controls worked, and document an evidence-backed classification. Do not assume the activity is malicious.\n\nTools and navigation\n1. Microsoft Sentinel > Incidents > open the linked incident.\n2. Log Analytics > secure-commerce-dev-law > Logs.\n3. Application Insights > Logs if request details require enrichment.\n4. GLPI > record findings and attach exported evidence.\n\nRunnable KQL - timeline\nContainerAppConsoleLogs_CL\n| where TimeGenerated > ago(30m)\n| extend payload=parse_json(Log_s)\n| project TimeGenerated, event_type=tostring(payload.event_type), simulation_id=tostring(payload.simulation_id), source_ip=tostring(payload.source_ip), request_id=tostring(payload.request_id), path=tostring(payload.path), status_code=toint(payload.status_code)\n| order by TimeGenerated asc\n\nRunnable KQL - scope\nContainerAppConsoleLogs_CL\n| where TimeGenerated > ago(1h)\n| extend payload=parse_json(Log_s)\n| summarize Events=count(), EventTypes=make_set(tostring(payload.event_type)), Paths=make_set(tostring(payload.path), 20), Sources=make_set(tostring(payload.source_ip)) by tostring(payload.simulation_id)\n| order by Events desc\n\nInvestigation checklist\n[ ] Confirm the Sentinel rule, incident number, severity and time window.\n[ ] Run both KQL queries and record matching timestamps, source IPs, simulation IDs and request IDs.\n[ ] Determine whether requests were blocked, rate-limited, unauthorized, or successful.\n[ ] Check related activity before and after the alert window.\n[ ] Preserve query results or screenshots as evidence.\n[ ] Escalate if unauthorized activity succeeded, scope is unclear, or evidence indicates impact.\n\nInvestigation outcome - Muhammad to complete\n- Incident classification:\n- Scope:\n- Timeline:\n- Observed indicators:\n- Alternative explanations:\n- Impact:\n- Recommended containment:\n- Evidence links:\n- Confidence level:\n- Final analyst conclusion:\n\nClosure criteria\nLeave this ticket open until the investigation is complete, evidence is attached, findings are documented, and Sentinel status and GLPI status are updated by an authorized analyst."
              itilcategories_id = 0
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

resource "azurerm_role_assignment" "log_analytics_reader" {
  scope                = var.workspace_id
  role_definition_name = "Log Analytics Reader"
  principal_id         = azurerm_logic_app_workflow.main.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_sentinel_automation_rule" "glpi" {
  name                       = "${var.name_prefix}-sentinel-to-glpi"
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
