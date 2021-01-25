resource "azurerm_user_assigned_identity" "aks_user_assigned_identity" {
  resource_group_name = var.aks_resource_group_name
  location            = var.location
  name = "${var.company}_${var.project}_${var.environment}_aks_user_assigned_identity"
}

resource "azurerm_role_assignment" "managed_identity_operator_assignment" {
  scope                = var.aks_managed_identity_assignment_scope
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.aks_user_assigned_identity.principal_id
  depends_on = [
    azurerm_user_assigned_identity.aks_user_assigned_identity
  ]
}

resource "azurerm_role_assignment" "virtual_machine_operator_assignment" {
  scope                = var.aks_managed_identity_assignment_scope
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_user_assigned_identity.principal_id
  depends_on = [
    azurerm_user_assigned_identity.aks_user_assigned_identity
  ]
}

data "azurerm_kubernetes_service_versions" "kubernetes_version" {
  location = var.location
  version_prefix = var.kubernetes_version_prefix
}

resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = "${var.company}_${var.project}_${var.environment}_aks"
  location            = var.location
  resource_group_name = var.aks_resource_group_name
  node_resource_group = var.aks_resource_group_name
  dns_prefix          = "${var.company}-${var.project}-${var.environment}-aks"
  kubernetes_version  = data.azurerm_kubernetes_service_versions.kubernetes_version.latest_version
  
  addon_profile {
    azure_policy {
      enabled = false
    }
    http_application_routing {
      enabled = false
    }
    kube_dashboard {
      enabled = false
    }
    oms_agent {
      enabled = false
    }
  }

  default_node_pool {
    name = "${var.company}_${var.project}_${var.environment}_aks_node_pool_default"
    vnet_subnet_id        = var.aks_subnet_id
    vm_size               = var.aks_node_vm_size
    type                  = "VirtualMachineScaleSets"
    enable_node_public_ip = var.aks_node_enable_public_ip
    availability_zones    = var.aks_node_availability_zones
    enable_auto_scaling   = var.aks_enable_auto_scaling
    node_count            = var.aks_node_count
    min_count             = var.aks_node_min
    max_count             = var.aks_node_max
    node_labels           = var.aks_node_labels
    orchestrator_version  = data.azurerm_kubernetes_service_versions.kubernetes_version.latest_version
  }

  identity {
    type = "UserAssigned"
    user_assigned_identity_id = azurerm_user_assigned_identity.aks_user_assigned_identity.id
  }

  network_profile {
    network_plugin     = "azure"
    load_balancer_sku  = "standard"
    network_policy     = "calico"
  }

  role_based_access_control {
    azure_active_directory {
      managed           = false
      client_app_id     = var.client_app_id
      server_app_id     = var.server_app_id
      server_app_secret = var.server_app_secret
      tenant_id         = var.tenant_id
    }    
    enabled = true
  }

  depends_on = [
    azurerm_user_assigned_identity.aks_user_assigned_identity
  ]

}