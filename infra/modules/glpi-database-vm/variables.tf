variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "peer_vnet_id" { type = string }
variable "peer_vnet_name" { type = string }
variable "peer_vnet_resource_group_name" { type = string }
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
  # Keep overridable because regional capacity changes over time.
  type    = string
  default = "Standard_B2s"
}
variable "tags" {
  type    = map(string)
  default = {}
}
