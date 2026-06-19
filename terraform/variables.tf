variable "resource_group_name" {
  type = string
}

variable "postgres_location" {
  default = "australiaeast"
}

variable "container_registry_name" {
  type = string
}

variable "azurerm_kubernetes_cluster" {
  type = string
}

variable "postgres_server_name" {}

variable "postgres_admin_username" {}

variable "postgres_admin_password" {
  sensitive = true
}

variable "postgres_database_name" {
  default = "books"
}