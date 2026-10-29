data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "state" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Project   = "secure-commerce"
    ManagedBy = "Terraform-bootstrap"
  }
}

resource "azurerm_role_assignment" "state_access" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_storage_account" "state" {
  #checkov:skip=CKV_AZURE_33:The backend does not use Azure Queue Storage; state access is captured by Azure control-plane activity logs.
  #checkov:skip=CKV_AZURE_59:Public routing is required for GitHub-hosted runners; data-plane access still requires Entra ID and public blob access is disabled.
  #checkov:skip=CKV_AZURE_206:LRS is an explicit cost choice for this disposable development lab; use ZRS/GRS for durable production state.
  #checkov:skip=CKV2_AZURE_33:A private endpoint would make the backend unreachable from GitHub-hosted runners without a self-hosted runner.
  #checkov:skip=CKV2_AZURE_1:Microsoft-managed encryption is proportionate for this disposable lab state; CMK adds a second bootstrap dependency.
  name                            = var.storage_account_name
  resource_group_name             = azurerm_resource_group.state.name
  location                        = azurerm_resource_group.state.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  tags = {
    Project   = "secure-commerce"
    ManagedBy = "Terraform-bootstrap"
  }
}

resource "azurerm_storage_container" "state" {
  #checkov:skip=CKV2_AZURE_21:Classic Storage Analytics blob logging is not configurable through this modern AzureRM container resource; control-plane activity is retained by Azure.
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"

  depends_on = [azurerm_role_assignment.state_access]
}
