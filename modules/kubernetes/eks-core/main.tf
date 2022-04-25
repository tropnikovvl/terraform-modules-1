/**
  * # EKS Core
  *
  * This module is used to configure EKS clusters.
  */

terraform {
  required_version = "0.15.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.36.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.0.3"
    }
    github = {
      source  = "integrations/github"
      version = "4.8.0"
    }
    flux = {
      source  = "fluxcd/flux"
      version = "0.1.3"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.10.0"
    }
  }
}

data "aws_region" "current" {}

data "aws_route53_zone" "this" {
  name = "${var.cert_manager_config.dns_zone}."
}

