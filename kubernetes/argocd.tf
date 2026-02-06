# =============================================================================
# ARGOCD
# =============================================================================
# PHASE 3: Deploys after cert-manager (needs ClusterIssuer for TLS)
# GitOps continuous delivery tool with GitHub SSO
#
# Resource allocation (conservative for 2-node cluster):
# - Server: 100m CPU, 256Mi memory
# - Repo Server: 100m CPU, 256Mi memory
# - Application Controller: 200m CPU, 512Mi memory
# - Dex: 50m CPU, 64Mi memory
# - Redis: 50m CPU, 64Mi memory
# Total: ~500m CPU, ~1.1GB memory
# =============================================================================

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }

  # Phase 3: Depends on cert-manager ClusterIssuer being ready
  depends_on = [kubectl_manifest.cluster_issuer]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.helm_versions.argocd
  namespace        = "argocd"
  create_namespace = false
  timeout          = 900

  values = [<<-YAML
    global:
      domain: argocd.${var.domain_name}

    configs:
      params:
        server.insecure: true
      cm:
        url: https://argocd.${var.domain_name}
        admin.enabled: "false"
        dex.config: |
          connectors:
            - type: github
              id: github
              name: GitHub
              config:
                clientID: ${var.argocd_github_client_id}
                clientSecret: ${var.argocd_github_client_secret}
                orgs:
                  - name: ${var.argocd_github_org}
      rbac:
        policy.default: role:readonly
        policy.csv: |
          p, role:admin, applications, *, */*, allow
          p, role:admin, clusters, *, *, allow
          p, role:admin, repositories, *, *, allow
          p, role:admin, projects, *, *, allow
          p, role:admin, logs, *, *, allow
          p, role:admin, exec, *, */*, allow
          g, ${join(", role:admin\n          g, ", var.argocd_admin_users)}, role:admin

    # Resource limits for Standard_D2as_v4 nodes
    server:
      replicas: 1
      resources:
        requests:
          cpu: 50m
          memory: 128Mi
        limits:
          cpu: 200m
          memory: 256Mi
      ingress:
        enabled: true
        ingressClassName: nginx
        annotations:
          cert-manager.io/cluster-issuer: letsencrypt
          nginx.ingress.kubernetes.io/backend-protocol: HTTP
          nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
        hosts:
          - argocd.${var.domain_name}
        tls:
          - secretName: argocd-tls
            hosts:
              - argocd.${var.domain_name}

    repoServer:
      replicas: 1
      resources:
        requests:
          cpu: 50m
          memory: 128Mi
        limits:
          cpu: 200m
          memory: 512Mi

    controller:
      resources:
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          cpu: 500m
          memory: 512Mi

    notifications:
      enabled: false

    dex:
      enabled: true
      resources:
        requests:
          cpu: 25m
          memory: 64Mi
        limits:
          cpu: 100m
          memory: 128Mi

    redis:
      enabled: true
      resources:
        requests:
          cpu: 25m
          memory: 64Mi
        limits:
          cpu: 100m
          memory: 128Mi
  YAML
  ]

  depends_on = [
    kubernetes_namespace.argocd,
    helm_release.ingress_nginx,
    kubectl_manifest.cluster_issuer,
  ]
}