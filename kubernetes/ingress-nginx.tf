# =============================================================================
# INGRESS NGINX
# =============================================================================
# PHASE 1: Deploys first (parallel with Kyverno) to provision Azure Load Balancer
#
# Resource allocation:
# - Controller: ~200m CPU, ~256Mi memory
# - Admission webhook: ~50m CPU, ~64Mi memory
# =============================================================================

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.helm_versions.ingress_nginx
  namespace        = "ingress-nginx"
  create_namespace = true
  timeout          = 600

  # --- Fast cleanup settings for dev environments ---
  disable_webhooks = true
  cleanup_on_fail  = true
  force_update     = true
  replace          = true
  wait             = false
  wait_for_jobs    = false

  # No dependencies - this is Phase 1

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
  }

  # Resource limits for Standard_D2as_v4 nodes
  set {
    name  = "controller.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "128Mi"
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = "500m"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "512Mi"
  }
}
