variable "location" {
  description = "Azure region for the Terraform state resources."
  type        = string
  default     = "UK South"
}

variable "resource_group_name" {
  description = "Resource group containing remote-state storage."
  type        = string
  default     = "secure-commerce-tfstate-rg"
}

variable "storage_account_name" {
  description = "Globally unique lowercase storage account name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must contain 3-24 lowercase letters and numbers."
  }
}

variable "container_name" {
  description = "Blob container used for Terraform state."
  type        = string
  default     = "tfstate"
}
