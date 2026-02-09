# =============================================================================
# KYVERNO - KUBERNETES POLICY ENGINE
# =============================================================================
# Kyverno is a policy engine designed for Kubernetes. It allows you to:
# - Validate: Block resources that don't meet policy requirements
# - Mutate: Automatically modify resources to meet requirements
# - Generate: Create additional resources based on triggers
#
# Resource allocation rationale for Standard_D2as_v4 (2 vCPU, 8GB RAM) x2 nodes:
# - Kyverno admission controller: 100m CPU, 256Mi memory (lightweight, critical path)
# - Kyverno background controller: 50m CPU, 128Mi memory (async processing)
# - Kyverno cleanup controller: 50m CPU, 128Mi memory (periodic cleanup)
# - Kyverno reports controller: 50m CPU, 128Mi memory (policy reports)
# Total: ~250m CPU, ~640Mi memory - leaves plenty for your applications
# =============================================================================

resource "helm_release" "kyverno" {
  count = var.enable_kyverno ? 1 : 0

  name             = "kyverno"
  repository       = "https://kyverno.github.io/kyverno"
  chart            = "kyverno"
  version          = var.helm_versions.kyverno
  namespace        = "kyverno"
  create_namespace = true
  timeout          = 600

  # Clean up webhooks before uninstalling to prevent deadlock
  cleanup_on_fail = true
  force_update    = false

  # This is critical - don't wait forever on destroy
  disable_webhooks = true   # Disables webhook validation during Helm operations


  # Kyverno deploys alongside ingress-nginx (no dependencies)
  # This is safe because Kyverno doesn't depend on any other cluster components

  values = [<<-YAML
    # Admission controller - validates/mutates resources at admission time
    admissionController:
      replicas: 1
      resources:
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          cpu: 500m
          memory: 512Mi

    # Background controller - handles generate/mutate policies asynchronously
    backgroundController:
      replicas: 1
      resources:
        requests:
          cpu: 50m
          memory: 128Mi
        limits:
          cpu: 200m
          memory: 256Mi

    # Cleanup controller - handles policy cleanup jobs
    cleanupController:
      replicas: 1
      resources:
        requests:
          cpu: 50m
          memory: 128Mi
        limits:
          cpu: 200m
          memory: 256Mi

    # Reports controller - generates policy reports
    reportsController:
      replicas: 1
      resources:
        requests:
          cpu: 50m
          memory: 128Mi
        limits:
          cpu: 200m
          memory: 256Mi

    # Install CRDs with Helm (required for policy resources)
    crds:
      install: true

    # Exclude system namespaces from policies to prevent breaking cluster components
    config:
      excludeGroups:
        - system:nodes
      excludeUsernames:
        - system:kube-scheduler
      webhooks:
        namespaceSelector:
          matchExpressions:
            - key: kubernetes.io/metadata.name
              operator: NotIn
              values:
                - kube-system
                - kube-public
                - kube-node-lease
                - kyverno
                - cilium
  YAML
  ]
}

# Wait for Kyverno CRDs to be ready before applying policies
resource "time_sleep" "wait_for_kyverno" {
  count = var.enable_kyverno ? 1 : 0

  depends_on      = [helm_release.kyverno]
  create_duration = "30s"
}
