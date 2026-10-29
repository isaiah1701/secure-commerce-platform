resource "azurerm_storage_account" "data" {
  #checkov:skip=CKV_AZURE_206:LRS is a cost-controlled lab choice for the isolated database volume.
  #checkov:skip=CKV_AZURE_33:Queue logging is irrelevant because this account is used only for Azure Files.
  #checkov:skip=CKV_AZURE_59:Container Apps Azure Files requires a reachable storage endpoint and the share is not public.
  #checkov:skip=CKV2_AZURE_40:Container Apps Azure Files integration requires shared-key authorization.
  #checkov:skip=CKV2_AZURE_38:Soft delete is not supported for this Azure Files provider configuration.
  #checkov:skip=CKV2_AZURE_41:SAS expiration is not used because the environment storage binding uses the account key.
  #checkov:skip=CKV2_AZURE_33:Private endpoint would require additional Container Apps storage networking.
  #checkov:skip=CKV2_AZURE_1:Microsoft-managed encryption is proportionate for this training lab.
  name                            = var.storage_account_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true
  tags                            = var.tags
}
resource "azurerm_storage_share" "data" {
  name               = "mariadb-data"
  storage_account_id = azurerm_storage_account.data.id
  quota              = 20
}
resource "azurerm_container_app_environment_storage" "data" {
  name                         = "glpi-mariadb-data"
  container_app_environment_id = var.container_app_environment_id
  account_name                 = azurerm_storage_account.data.name
  access_key                   = azurerm_storage_account.data.primary_access_key
  share_name                   = azurerm_storage_share.data.name
  access_mode                  = "ReadWrite"
}
