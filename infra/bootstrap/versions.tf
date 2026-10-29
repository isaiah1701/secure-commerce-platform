terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.4"
    }
  }
}

provider "azurerm" {
  features {}

  # The state account disables shared keys, so bootstrap data-plane operations
  # must use the caller's Entra ID role assignment.
  storage_use_azuread = true
}
