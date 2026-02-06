provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  client_id       = var.arm_client_id
  client_secret   = var.arm_client_secret
  tenant_id       = var.arm_tenant_id
  subscription_id = var.arm_subscription_id
}


provider "azuread" {
  client_id     = var.arm_client_id
  client_secret = var.arm_client_secret
  tenant_id     = var.arm_tenant_id
}

provider "kubernetes" {
  host                   = module.aks.cluster_host
  client_certificate     = base64decode(module.aks.cluster_client_certificate)
  client_key             = base64decode(module.aks.cluster_client_key)
  cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = module.aks.cluster_host
    client_certificate     = base64decode(module.aks.cluster_client_certificate)
    client_key             = base64decode(module.aks.cluster_client_key)
    cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
  }
}

provider "kubectl" {
  host                   = module.aks.cluster_host
  client_certificate     = base64decode(module.aks.cluster_client_certificate)
  client_key             = base64decode(module.aks.cluster_client_key)
  cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
  load_config_file       = false
}
