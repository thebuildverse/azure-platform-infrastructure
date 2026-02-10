# =============================================================================
# CONFIGURATION
# =============================================================================
# Edit this file to configure your deployment.
# All other files should not require modification for basic usage.
# =============================================================================

# Update organization and workspace names for your environment
terraform { 
  cloud { 
    
    organization = "buildverse" 

    workspaces { 
      name = "dev" 
    } 
  }
}

locals {
  # ---------------------------------------------------------------------------
  # ENVIRONMENT
  # ---------------------------------------------------------------------------
  environment = "dev"
  location    = "eastus"
  project     = "platform"

  # Resource naming: {project}-{resource}-{environment}-{location_short}
  location_short = "eus"
  name_prefix    = "${local.project}-${local.environment}-${local.location_short}"

  # Common tags applied to all resources
  tags = {
    Environment = local.environment
    Project     = local.project
    ManagedBy   = "terraform"
    Repository  = "https://github.com/thebuildverse/azure-platform-infrastructure"
  }

  # ---------------------------------------------------------------------------
  # DNS (Must exist before deployment - see README.md)
  # ---------------------------------------------------------------------------
  dns = {
    zone_name           = "buildverse.site"
    zone_resource_group = "dns-zone-rg"
    cert_manager_email  = "belalelgebaly11@gmail.com"
  }

  # ---------------------------------------------------------------------------
  # NETWORKING
  # ---------------------------------------------------------------------------
  network = {
    vnet_address_space = ["10.0.0.0/8"]

    subnets = {
      nodes = {
        name   = "snet-aks-nodes"
        prefix = "10.240.0.0/16"
      }
      pods = {
        name   = "snet-aks-pods"
        prefix = "10.241.0.0/16"
      }
    }
  }

  # ---------------------------------------------------------------------------
  # AKS CLUSTER
  # ---------------------------------------------------------------------------
  aks = {
    kubernetes_version = "1.32.10"
    sku_tier           = "Free" # Use "Standard" for production SLA

    default_node_pool = {
      name                = "system"
      vm_size             = "Standard_D2as_v4"
      os_disk_size_gb     = 128
      os_sku              = "AzureLinux"
      enable_auto_scaling = true
      node_count          = 2 # Used when auto_scaling = false
      min_count           = 1 # Used when auto_scaling = true
      max_count           = 2 # Used when auto_scaling = true
    }
  }

  # ---------------------------------------------------------------------------
  # CONTAINER REGISTRY
  # ---------------------------------------------------------------------------
  acr = {
    sku           = "Basic" # Basic, Standard, or Premium
    admin_enabled = true    # Disable for production
  }

  # ---------------------------------------------------------------------------
  # MONITORING
  # ---------------------------------------------------------------------------
  monitoring = {
    grafana_sku           = "Standard"
    log_retention_days    = 30
    grafana_major_version = 11
  }

  # ---------------------------------------------------------------------------
  # ARGOCD
  # ---------------------------------------------------------------------------
  # Prerequisites:
  # 1. Create GitHub OAuth App (Settings → Developer settings → OAuth Apps)
  # 2. Store the credentials on terrraform cloud 
  argocd = {
    github_org  = "thebuildverse"
    admin_users = ["bytiv"] # GitHub usernames with admin access
  }

  # ---------------------------------------------------------------------------
  # SECURITY POLICIES
  # ---------------------------------------------------------------------------
  # Toggle Kyverno and Cilium policies on/off
  # Set to false to disable policies (useful for debugging or dev environments)
  security = {
    # Kyverno - Kubernetes admission controller for policy enforcement
    # When enabled, deploys Kyverno and optionally its policies
    enable_kyverno         = true  # Deploy Kyverno Helm chart
    enable_kyverno_policies = true # Apply Kyverno policies (requires enable_kyverno = true)

    # Cilium Network Policies - Zero-trust network security
    # When enabled, applies CiliumNetworkPolicies to restrict pod communication
    enable_cilium_policies = false

    # Image Registry Restriction - Only allow images from approved registries
    # When enabled, Kyverno will only allow images from allowed_registries list
    enable_registry_restriction = false # Set to true to restrict registries

    # Allowed container registries (used when enable_registry_restriction = true)
    # Add your ACR and any other registries your apps need
    allowed_registries = [
      "*.azurecr.io/",         # Azure Container Registry (your ACR)
      "registry.k8s.io/",       # Kubernetes official images
      "docker.io/",             # Docker Hub
      "ghcr.io/",               # GitHub Container Registry
      "quay.io/",               # Red Hat Quay
      "mcr.microsoft.com/"      # Microsoft Container Registry
    ]
  }

  # ---------------------------------------------------------------------------
  # HELM CHART VERSIONS (Pinned for reproducibility)
  # ---------------------------------------------------------------------------
  helm_versions = {
    ingress_nginx    = "4.11.3"
    cert_manager     = "1.16.2"
    external_dns     = "8.5.1"
    external_secrets = "0.10.7"
    argocd           = "7.7.4"
    kyverno          = "3.3.4"
  }
}
