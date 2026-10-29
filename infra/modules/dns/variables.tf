variable "domain_name" {
  description = "Optional Azure DNS public zone name."
  type        = string
}

variable "app_subdomain" {
  description = "Application record label within the public zone."
  type        = string
}

variable "enable_custom_domain_binding" {
  description = "Whether DNS is delegated and the Container App managed-certificate binding can be created."
  type        = bool
}

variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "container_app_id" {
  description = "Container App resource ID."
  type        = string
}

variable "container_app_fqdn" {
  description = "Default Container App ingress hostname."
  type        = string
}

variable "custom_domain_verification_id" {
  description = "Container App custom-domain verification value."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Azure resource tags."
  type        = map(string)
  default     = {}
}
