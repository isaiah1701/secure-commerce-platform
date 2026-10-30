variable "name" { type = string }
variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "container_app_environment_id" { type = string }
variable "acr_id" { type = string }
variable "acr_login_server" { type = string }
variable "key_vault_id" { type = string }
variable "database_host" { type = string }

variable "database_name" {
  type    = string
  default = "glpi"
}

variable "database_user" {
  type    = string
  default = "glpiadmin"
}

variable "database_password" {
  type      = string
  sensitive = true
}

variable "storage_account_name" { type = string }

variable "image" {
  type    = string
  default = "glpi/glpi:10.0.28"
}

variable "domain_name" {
  type    = string
  default = ""
}

variable "subdomain" {
  type    = string
  default = "ticket"
}

variable "min_replicas" {
  type    = number
  default = 1
}

variable "max_replicas" {
  type    = number
  default = 1
}

variable "tags" {
  type    = map(string)
  default = {}
}
