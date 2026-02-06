# =============================================================================
# KUBERNETES MODULE - HELM DEPLOYMENTS
# =============================================================================
# This module orchestrates the deployment of Kubernetes components with
# optimized parallelization for faster provisioning while respecting dependencies.
#
# Deployment Order (optimized for 2-node cluster with Standard_D2as_v4):
# ┌─────────────────────────────────────────────────────────────────────────┐
# │ PHASE 1 (Parallel - no dependencies):                                   │
# │   - ingress-nginx (provisions Azure Load Balancer)                      │
# │   - kyverno (policy engine, lightweight)                                │
# ├─────────────────────────────────────────────────────────────────────────┤
# │ PHASE 2 (Parallel - depends on ingress-nginx):                          │
# │   - cert-manager (TLS certificates)                                     │
# │   - external-dns (DNS record management)                                │
# ├─────────────────────────────────────────────────────────────────────────┤
# │ PHASE 3 (depends on cert-manager):                                      │
# │   - argocd (GitOps, needs TLS)                                          │
# ├─────────────────────────────────────────────────────────────────────────┤
# │ PHASE 4 (depends on argocd):                                            │
# │   - external-secrets (secret sync)                                      │
# └─────────────────────────────────────────────────────────────────────────┘
#
# Resource considerations for Standard_D2as_v4 (2 vCPU, 8GB RAM per node):
# - Total cluster capacity: 4 vCPU, 16GB RAM (with 2 nodes)
# - System reservations: ~0.5 vCPU, ~1GB RAM per node
# - Available for workloads: ~3 vCPU, ~14GB RAM
# - Phase 1 uses: ~500m CPU, ~1GB RAM (safe to parallelize)
# - Phase 2 uses: ~300m CPU, ~512MB RAM (safe to parallelize)
# =============================================================================

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.35"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.17"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.1"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.12"
    }
  }
}

# =============================================================================
# DEPLOYMENT ORCHESTRATION - TIME SLEEPS
# =============================================================================
# These time_sleeps ensure components are fully ready before dependents start.
# We use minimal wait times since we rely on Helm's --wait flag where possible.

# Wait for ingress-nginx LoadBalancer to be provisioned
# This is needed because cert-manager and external-dns need the LB IP
resource "time_sleep" "wait_for_ingress" {
  depends_on      = [helm_release.ingress_nginx]
  create_duration = "20s" # Reduced from 30s - LB provisions quickly in Azure
}

# Wait for cert-manager CRDs and webhook to be ready
# ClusterIssuer creation needs the webhook to be available
resource "time_sleep" "wait_for_cert_manager_webhook" {
  depends_on      = [helm_release.cert_manager]
  create_duration = "15s"
}

# Wait for external-secrets CRDs to be ready
resource "time_sleep" "wait_for_external_secrets" {
  depends_on      = [helm_release.external_secrets]
  create_duration = "10s"
}

