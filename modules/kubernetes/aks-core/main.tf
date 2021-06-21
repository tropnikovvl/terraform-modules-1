/**
  * # AKS Core
  *
  * This module is used to create AKS clusters.
  */

terraform {
  required_version = "0.15.3"

  required_providers {
    azurerm = {
      version = "2.64.0"
      source  = "hashicorp/azurerm"
    }
    azuread = {
      version = "1.5.1"
      source  = "hashicorp/azuread"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.3.2"
    }
    github = {
      source  = "integrations/github"
      version = "4.12.0"
    }
    flux = {
      source  = "fluxcd/flux"
      version = "0.1.11"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.11.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.2.0"
    }
  }
}

locals {
  # Namespace to create service accounts in
  service_accounts_namespace = "service-accounts"
}

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "this" {
  name = "rg-${var.environment}-${var.location_short}-${var.name}"
}
