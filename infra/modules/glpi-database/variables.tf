variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "delegated_subnet_id" { type = string }
variable "private_dns_zone_id" { type = string }
variable "administrator_login" { type = string }

variable "administrator_password" {
  type      = string
  sensitive = true
}

variable "database_name" {
  type    = string
  default = "glpi"
}

variable "sku_name" {
  type    = string
  default = "B_Standard_B1ms"
}

variable "log_analytics_workspace_id" { type = string }

variable "tags" {
  type    = map(string)
  default = {}
}
