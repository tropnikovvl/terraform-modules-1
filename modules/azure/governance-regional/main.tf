/**
  * # Governance (Regional)
  *
  * This module is used for governance on a regional level and not using any specific resource groups. Replaces the old `governance` together with `governance-global`.
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
    random = {
      version = "3.4.3"
      source  = "hashicorp/random"
    }
    pal = {
      version = "0.2.5"
      source  = "xenitab/pal"
    }
  }
}

data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}
