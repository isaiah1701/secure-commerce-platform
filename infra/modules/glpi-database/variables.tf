variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "container_app_environment_id" { type = string }
variable "database_password" {
  type      = string
  sensitive = true
}
variable "log_analytics_workspace_id" { type = string }
variable "storage_account_name" { type = string }
variable "database_name" {
  type    = string
  default = "glpi"
}
variable "database_user" {
  type    = string
  default = "glpiadmin"
}
variable "image" {
  type    = string
  default = "mariadb:10.11"
}
variable "tags" {
  type    = map(string)
  default = {}
}
