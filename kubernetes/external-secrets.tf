# =============================================================================
# EXTERNAL SECRETS OPERATOR
# =============================================================================
# PHASE 4: Deploys after ArgoCD (last in chain)
# Syncs secrets from Azure Key Vault to Kubernetes
#
# Resource allocation:
# - Controller: ~50m CPU, ~128Mi memory
# - Webhook: ~25m CPU, ~64Mi memory
# - Cert Controller: ~25m CPU, ~64Mi memory
# =============================================================================

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.helm_versions.external_secrets
  namespace        = "external-secrets"
  create_namespace = true
  timeout          = 600

  # Phase 4: Depends on ArgoCD being ready
  depends_on = [helm_release.argocd]

  values = [<<-YAML
    serviceAccount:
      create: true
      name: external-secrets
      annotations:
        azure.workload.identity/client-id: ${var.external_secrets_identity_client_id}

    podLabels:
      azure.workload.identity/use: "true"

    # Resource limits for Standard_D2as_v4 nodes
    resources:
      requests:
        cpu: 25m
        memory: 64Mi
      limits:
        cpu: 100m
        memory: 256Mi

    webhook:
      resources:
        requests:
          cpu: 10m
          memory: 32Mi
        limits:
          cpu: 50m
          memory: 128Mi

    certController:
      resources:
        requests:
          cpu: 10m
          memory: 32Mi
        limits:
          cpu: 50m
          memory: 128Mi
  YAML
  ]
}

resource "kubectl_manifest" "cluster_secret_store" {
  yaml_body = <<-YAML
    apiVersion: external-secrets.io/v1beta1
    kind: ClusterSecretStore
    metadata:
      name: azure-keyvault
    spec:
      provider:
        azurekv:
          authType: WorkloadIdentity
          vaultUrl: ${var.keyvault_uri}
          serviceAccountRef:
            name: external-secrets
            namespace: external-secrets
  YAML

  depends_on = [time_sleep.wait_for_external_secrets]
}