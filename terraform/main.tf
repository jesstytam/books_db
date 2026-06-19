# Configure the Azure provider

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

#call existing resource
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

#create container registry
resource "azurerm_container_registry" "acr" {
  name = var.container_registry_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location = data.azurerm_resource_group.rg.location
  sku = "Basic"
  admin_enabled = false
}