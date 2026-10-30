variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "resource_group_id" { type = string }
variable "sentinel_service_principal_object_id" { type = string }
variable "workspace_id" { type = string }
variable "workspace_customer_id" { type = string }
variable "key_vault_id" { type = string }
variable "key_vault_name" { type = string }
variable "glpi_api_url" { type = string }

variable "tags" {
  type    = map(string)
  default = {}
}
