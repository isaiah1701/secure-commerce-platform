data "azurerm_managed_api" "sentinel" {
  name     = "azuresentinel"
  location = var.location
}

locals {
  workflow_actions = jsondecode(templatefile("${path.module}/workflow-actions.json.tftpl", {
    key_vault_name        = var.key_vault_name
    glpi_api_url          = trim(var.glpi_api_url, "/")
    workspace_customer_id = var.workspace_customer_id
    workspace_id          = var.workspace_id
    workspace_id_lower    = lower(var.workspace_id)
    tenant_id             = var.tenant_id
    app_name              = "${var.name_prefix}-app"
  }))
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
    runtimeConfiguration = { concurrency = { runs = 1 } }
    type                 = "ApiConnectionWebhook"
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

resource "azurerm_logic_app_action_custom" "validate_incident" {
  name         = "Validate_Incident"
  logic_app_id = azurerm_logic_app_workflow.main.id
  body         = jsonencode(local.workflow_actions["Validate_Incident"])
  depends_on   = [azurerm_logic_app_trigger_custom.sentinel_incident]
}

resource "azurerm_logic_app_action_custom" "get_glpi_username" {
  name         = "Get_GLPI_API_Username"
  logic_app_id = azurerm_logic_app_workflow.main.id
  body         = jsonencode(local.workflow_actions["Get_GLPI_API_Username"])
  depends_on   = [azurerm_logic_app_action_custom.validate_incident]
}

resource "azurerm_logic_app_action_custom" "get_glpi_password" {
  name         = "Get_GLPI_API_Password"
  logic_app_id = azurerm_logic_app_workflow.main.id
  body         = jsonencode(local.workflow_actions["Get_GLPI_API_Password"])
  depends_on   = [azurerm_logic_app_action_custom.validate_incident]
}

resource "azurerm_logic_app_action_custom" "get_glpi_app_token" {
  name         = "Get_GLPI_App_Token"
  logic_app_id = azurerm_logic_app_workflow.main.id
  body         = jsonencode(local.workflow_actions["Get_GLPI_App_Token"])
  depends_on   = [azurerm_logic_app_action_custom.validate_incident]
}

resource "azurerm_logic_app_action_custom" "init_glpi_session" {
  name         = "Init_GLPI_Session"
  logic_app_id = azurerm_logic_app_workflow.main.id
  body         = jsonencode(local.workflow_actions["Init_GLPI_Session"])
  depends_on   = [azurerm_logic_app_action_custom.get_glpi_username, azurerm_logic_app_action_custom.get_glpi_password, azurerm_logic_app_action_custom.get_glpi_app_token]
}

resource "azurerm_logic_app_action_custom" "query_log_analytics" {
  name         = "Query_Commerce_Evidence"
  logic_app_id = azurerm_logic_app_workflow.main.id
  body         = jsonencode(local.workflow_actions["Query_Commerce_Evidence"])
  depends_on   = [azurerm_logic_app_action_custom.init_glpi_session]
}

resource "azurerm_logic_app_action_custom" "search_existing_ticket" {
  name         = "Search_Existing_GLPI_Ticket"
  logic_app_id = azurerm_logic_app_workflow.main.id
  body         = jsonencode(local.workflow_actions["Search_Existing_GLPI_Ticket"])
  depends_on   = [azurerm_logic_app_action_custom.query_log_analytics]
}

resource "azurerm_logic_app_action_custom" "validate_search" {
  name         = "Validate_GLPI_Search"
  logic_app_id = azurerm_logic_app_workflow.main.id
  body         = jsonencode(local.workflow_actions["Validate_GLPI_Search"])
  depends_on   = [azurerm_logic_app_action_custom.search_existing_ticket]
}

resource "azurerm_logic_app_action_custom" "filter_existing" {
  name         = "Filter_Existing_GLPI_Tickets"
  logic_app_id = azurerm_logic_app_workflow.main.id
  body         = jsonencode(local.workflow_actions["Filter_Existing_GLPI_Tickets"])
  depends_on   = [azurerm_logic_app_action_custom.validate_search]
}

resource "azurerm_logic_app_action_custom" "create_if_missing" {
  name         = "Create_GLPI_Ticket_If_Missing"
  logic_app_id = azurerm_logic_app_workflow.main.id
  body         = jsonencode(local.workflow_actions["Create_GLPI_Ticket_If_Missing"])
  depends_on   = [azurerm_logic_app_action_custom.filter_existing]
}

resource "azurerm_logic_app_action_custom" "close_session" {
  name         = "Close_GLPI_Session"
  logic_app_id = azurerm_logic_app_workflow.main.id
  body         = jsonencode(local.workflow_actions["Close_GLPI_Session"])
  depends_on   = [azurerm_logic_app_action_custom.create_if_missing]
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
