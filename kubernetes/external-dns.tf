# =============================================================================
# EXTERNAL DNS
# =============================================================================
# PHASE 2: Deploys after ingress-nginx (parallel with cert-manager)
# Automatically manages Azure DNS records for ingress resources
#
# Resource allocation:
# - Controller: ~50m CPU, ~64Mi memory (very lightweight)
# =============================================================================

resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "external-dns"
  version          = "8.3.9"
  namespace        = "external-dns"
  create_namespace = true
  atomic           = true
  timeout          = 600

  # --- Fast cleanup settings for dev environments ---
  # Prevents webhook deadlocks during destroy (e.g., Kyverno/ArgoCD webhooks
  # blocking their own deletion), skips waiting for graceful pod termination,
  # and ensures Helm doesn't hang on failed or stuck releases.
  disable_webhooks = true
  cleanup_on_fail  = true
  force_update     = true
  replace          = true
  wait             = false
  wait_for_jobs    = false

  # Phase 2: Depends on ingress-nginx being ready (parallel with cert-manager)
  depends_on = [time_sleep.wait_for_ingress]

values = [<<-YAML
    image:
      registry: registry.k8s.io
      repository: external-dns/external-dns
      tag: v0.14.2

    provider: azure

    policy: sync
    registry: txt
    txtOwnerId: ${var.name_prefix}
    txtPrefix: externaldns-

    azure:
      subscriptionId: ${var.subscription_id}
      tenantId: ${var.tenant_id}
      resourceGroup: ${var.dns_zone_resource_group}
      useWorkloadIdentityExtension: true

    serviceAccount:
      create: true
      name: external-dns
      annotations:
        azure.workload.identity/client-id: ${var.external_dns_identity_client_id}

    podLabels:
      azure.workload.identity/use: "true"

    metrics:
      enabled: true

    # Resource limits for Standard_D2as_v4 nodes
    resources:
      requests:
        cpu: 25m
        memory: 64Mi
      limits:
        cpu: 100m
        memory: 128Mi
  YAML
  ]
}
