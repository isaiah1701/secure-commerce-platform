variable "name" {
  description = "Globally unique Key Vault name."
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

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
}

variable "deployment_principal_object_id" {
  description = "Object ID of the Terraform deployment principal."
  type        = string
}

variable "app_identity_principal_id" {
  description = "Principal ID of the Container App user-assigned identity."
  type        = string
}

variable "postgres_admin_username" {
  description = "PostgreSQL administrator username."
  type        = string
}

variable "postgres_admin_password" {
  description = "PostgreSQL administrator password."
  type        = string
  sensitive   = true
}

variable "postgres_fqdn" {
  description = "PostgreSQL Flexible Server hostname."
  type        = string
}

variable "postgres_database_name" {
  description = "PostgreSQL database name."
  type        = string
}

variable "jwt_secret" {
  description = "JWT signing secret."
  type        = string
  sensitive   = true
}

variable "application_insights_connection_string" {
  description = "Application Insights connection string."
  type        = string
  sensitive   = true
}

variable "log_analytics_workspace_id" {
  description = "Workspace receiving Key Vault diagnostics."
  type        = string
}

variable "tags" {
  description = "Azure resource tags."
  type        = map(string)
  default     = {}
}
