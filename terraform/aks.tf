resource "azurerm_kubernetes_cluster" "aks" {
  name = var.azurerm_kubernetes_cluster
  location = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  #kubernetes setup
  dns_prefix          = "booksdb"
  default_node_pool {
    name       = "default" #larger companies may have frontend-pool, backend-pool, etc.
    node_count = 1 
    vm_size    = "Standard_B2als_v2" #cheapest possible VM for K8s
  }
  identity {
    type = "SystemAssigned" #creates AKS Identity for assigning permissions to
  }
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id #kublet_identity will exist after aks is created
  role_definition_name = "AcrPull"
  scope = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}