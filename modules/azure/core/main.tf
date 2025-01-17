/**
  * # Core
  *
  * This module is used to create core resources like virtual network for the subscription.
  */

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    azurerm = {
      version = "3.28.0"
      source  = "hashicorp/azurerm"
    }
    azuread = {
      version = "2.28.1"
      source  = "hashicorp/azuread"
    }
  }
}
