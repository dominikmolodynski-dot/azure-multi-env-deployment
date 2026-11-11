terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Partial configuration: the storage account and the state key (one per
  # environment) are passed with -backend-config at `terraform init`.
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}
