variable "name" {
  description = "PostgreSQL Flexible Server name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "delegated_subnet_id" {
  description = "Delegated database subnet resource ID."
  type        = string
}

variable "private_dns_zone_id" {
  description = "PostgreSQL private DNS zone resource ID."
  type        = string
}

variable "administrator_login" {
  description = "PostgreSQL administrator login."
  type        = string
}

variable "administrator_password" {
  description = "PostgreSQL administrator password."
  type        = string
  sensitive   = true
}

variable "database_name" {
  description = "Application database name."
  type        = string
}

variable "sku_name" {
  description = "PostgreSQL compute SKU."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Workspace receiving PostgreSQL diagnostics."
  type        = string
}

variable "tags" {
  description = "Azure resource tags."
  type        = map(string)
  default     = {}
}
