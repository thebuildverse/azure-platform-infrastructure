# =============================================================================
# CERT-MANAGER
# =============================================================================
# PHASE 2: Deploys after ingress-nginx (parallel with external-dns)
# Manages TLS certificates via Let's Encrypt
#
# Resource allocation:
# - Controller: ~50m CPU, ~64Mi memory
# - Webhook: ~50m CPU, ~64Mi memory
# - CA Injector: ~50m CPU, ~64Mi memory
# =============================================================================

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.helm_versions.cert_manager
  namespace        = "cert-manager"
  create_namespace = true
  timeout          = 600

  # --- Fast cleanup settings for dev environments ---
  disable_webhooks = true
  cleanup_on_fail  = true
  force_update     = true
  replace          = true
  wait             = false
  wait_for_jobs    = false

  # Phase 2: Depends on ingress-nginx being ready
  depends_on = [time_sleep.wait_for_ingress]

  set {
    name  = "crds.enabled"
    value = "true"
  }

  # Resource limits for Standard_D2as_v4 nodes
  set {
    name  = "resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "resources.limits.memory"
    value = "256Mi"
  }

  set {
    name  = "webhook.resources.requests.cpu"
    value = "25m"
  }

  set {
    name  = "webhook.resources.requests.memory"
    value = "32Mi"
  }

  set {
    name  = "webhook.resources.limits.cpu"
    value = "100m"
  }

  set {
    name  = "webhook.resources.limits.memory"
    value = "128Mi"
  }

  set {
    name  = "cainjector.resources.requests.cpu"
    value = "25m"
  }

  set {
    name  = "cainjector.resources.requests.memory"
    value = "64Mi"
  }

  set {
    name  = "cainjector.resources.limits.cpu"
    value = "100m"
  }

  set {
    name  = "cainjector.resources.limits.memory"
    value = "256Mi"
  }

  set {
    name  = "crds.keep"
    value = "false"
  }
}

resource "kubectl_manifest" "cluster_issuer" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: ${var.cert_manager_email}
        privateKeySecretRef:
          name: letsencrypt-account-key
        solvers:
          - http01:
              ingress:
                class: nginx
  YAML

  depends_on = [time_sleep.wait_for_cert_manager_webhook]
}