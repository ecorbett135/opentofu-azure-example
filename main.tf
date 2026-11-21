terraform {
  required_version = "= 1.13.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.65.0"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}

  resource_provider_registrations = "none"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group to manage."
  default     = "rg-opentofu-example"
}

variable "location" {
  type        = string
  description = "Azure region for the resource group."
  default     = "eastus"
}

resource "azurerm_resource_group" "example" {
  name     = var.resource_group_name
  location = var.location
}
