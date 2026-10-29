variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "subnet_id" { type = string }
variable "admin_password" {
  type      = string
  sensitive = true
}
variable "database_password" {
  type      = string
  sensitive = true
}
variable "log_analytics_workspace_id" { type = string }
variable "vm_size" {
  type    = string
  default = "Standard_D2as_v5"
}
variable "tags" {
  type    = map(string)
  default = {}
}
