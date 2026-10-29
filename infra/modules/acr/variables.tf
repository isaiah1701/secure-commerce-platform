variable "name" {
  description = "Globally unique Azure Container Registry name."
  type        = string
}

variable "identity_name" {
  description = "User-assigned identity name for the Container App."
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

variable "log_analytics_workspace_id" {
  description = "Workspace receiving ACR diagnostic logs."
  type        = string
}

variable "deployment_principal_object_id" {
  description = "Object ID of the CI/Terraform principal that pushes images."
  type        = string
}

variable "tags" {
  description = "Azure resource tags."
  type        = map(string)
  default     = {}
}
