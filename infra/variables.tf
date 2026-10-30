variable "project_name" {
  description = "Short project name used in Azure resource names."
  type        = string
  default     = "secure-commerce"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,10}$", var.environment))
    error_message = "environment must contain 2-10 lowercase letters, numbers, or hyphens."
  }
}

variable "location" {
  description = "Azure region for all regional resources."
  type        = string
  default     = "UK South"
}

variable "resource_suffix" {
  description = "Optional lowercase suffix for globally unique ACR and Key Vault names."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-z0-9]{0,6}$", var.resource_suffix))
    error_message = "resource_suffix must contain at most six lowercase letters or numbers."
  }
}

variable "domain_name" {
  description = "Optional public DNS zone, for example example.com. Leave empty to use the Container Apps hostname."
  type        = string
  default     = ""
}

variable "app_subdomain" {
  description = "DNS label created inside domain_name."
  type        = string
  default     = "shop"
}

variable "enable_custom_domain_binding" {
  description = "Bind the custom hostname and request its managed certificate after DNS delegation has propagated."
  type        = bool
  default     = false
}

variable "postgres_admin_username" {
  description = "PostgreSQL administrator login."
  type        = string
  default     = "commerceadmin"
}

variable "postgres_admin_password" {
  description = "PostgreSQL administrator password. Supply with TF_VAR_postgres_admin_password."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.postgres_admin_password) >= 16
    error_message = "postgres_admin_password must be at least 16 characters."
  }
}

variable "jwt_secret" {
  description = "JWT signing secret. Supply with TF_VAR_jwt_secret."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.jwt_secret) >= 32
    error_message = "jwt_secret must be at least 32 characters."
  }
}

variable "deployment_principal_object_id" {
  description = "Object ID granted Terraform deployment permissions. Defaults to the current Azure identity."
  type        = string
  default     = null
}

variable "enable_glpi" {
  description = "Deploy the isolated GLPI SOC ticketing workload."
  type        = bool
  default     = false
}

variable "glpi_database_password" {
  description = "GLPI MySQL administrator/application password."
  type        = string
  sensitive   = true
  default     = null

  validation {
    condition     = var.glpi_database_password == null || length(var.glpi_database_password) >= 16
    error_message = "glpi_database_password must be at least 16 characters when GLPI is enabled."
  }
}

variable "glpi_database_host" {
  description = "External managed MySQL-compatible hostname for GLPI."
  type        = string
  default     = null
}

variable "enable_soc" {
  description = "Deploy Sentinel scheduled detections."
  type        = bool
  default     = true
}

variable "enable_soar" {
  description = "Deploy the Sentinel incident to GLPI Logic App playbook."
  type        = bool
  default     = false
}

variable "glpi_api_username" {
  description = "Dedicated GLPI API integration username."
  type        = string
  sensitive   = true
  default     = null
}

variable "glpi_api_password" {
  description = "Dedicated GLPI API integration password."
  type        = string
  sensitive   = true
  default     = null
}

variable "glpi_app_token" {
  description = "GLPI API application token."
  type        = string
  sensitive   = true
  default     = null
}

variable "glpi_image" {
  description = "Pinned official GLPI container image."
  type        = string
  default     = "glpi/glpi:11.0.12"
}

variable "container_image" {
  description = "Container repository without a tag. The public placeholder permits infrastructure bootstrapping."
  type        = string
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld"
}

variable "container_image_tag" {
  description = "Initial container image tag. Application CD deploys immutable Git SHA tags after bootstrap."
  type        = string
  default     = "latest"
}

variable "postgres_sku_name" {
  description = "Development-sized PostgreSQL Flexible Server SKU."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "glpi_mysql_sku_name" {
  description = "Development-sized Azure MySQL Flexible Server SKU."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "container_min_replicas" {
  description = "Minimum Container App replicas. Zero minimizes idle development cost."
  type        = number
  default     = 0
}

variable "container_max_replicas" {
  description = "Maximum Container App replicas."
  type        = number
  default     = 2
}

variable "tags" {
  description = "Additional Azure resource tags."
  type        = map(string)
  default     = {}
}
