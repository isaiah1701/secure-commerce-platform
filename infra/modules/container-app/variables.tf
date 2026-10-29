variable "name" {
  description = "Container App name."
  type        = string
}

variable "environment_name" {
  description = "Container Apps managed environment name."
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

variable "infrastructure_subnet_id" {
  description = "Subnet used by the Container Apps environment."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace connected to the managed environment."
  type        = string
}

variable "identity_id" {
  description = "User-assigned identity used for ACR and Key Vault."
  type        = string
}

variable "acr_login_server" {
  description = "Azure Container Registry login server."
  type        = string
}

variable "container_image" {
  description = "Initial fully qualified container image including tag."
  type        = string
}

variable "database_url_secret_id" {
  description = "Versionless Key Vault secret ID for DATABASE_URL."
  type        = string
}

variable "jwt_secret_id" {
  description = "Versionless Key Vault secret ID for JWT_SECRET."
  type        = string
}

variable "application_insights_connection_string_secret_id" {
  description = "Versionless Key Vault secret ID for Application Insights."
  type        = string
}

variable "min_replicas" {
  description = "Minimum number of replicas."
  type        = number
}

variable "max_replicas" {
  description = "Maximum number of replicas."
  type        = number
}

variable "tags" {
  description = "Azure resource tags."
  type        = map(string)
  default     = {}
}
