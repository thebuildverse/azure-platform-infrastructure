# =============================================================================
# CILIUM NETWORK POLICIES (Simplified)
# =============================================================================
# Secures application namespaces ("default" and "apps-*") with zero-trust:
#   1. Default deny all traffic in app namespaces
#   2. Allow DNS resolution cluster-wide
#   3. Allow ingress from ingress-nginx controller
#   4. Allow egress to internet (HTTPS) and cluster services
#
# Toggle: Set enable_cilium_policies = false in locals.tf to disable
#
# NOTE: Infrastructure namespaces (ingress-nginx, cert-manager, argocd, etc.)
#       are left unscoped — Cilium's default behavior allows all traffic in
#       namespaces without policies applied, so infra keeps working.
# =============================================================================

# =============================================================================
# DEFAULT DENY — "default" NAMESPACE
# =============================================================================
# Blocks all ingress/egress for pods in the "default" namespace.
# Every workload here needs an explicit allow policy.
# =============================================================================

resource "kubectl_manifest" "cilium_default_deny_default_ns" {
  count = var.enable_cilium_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumNetworkPolicy
    metadata:
      name: default-deny
      namespace: default
    spec:
      description: "Default deny all traffic in default namespace"
      endpointSelector: {}
      ingress:
        - {}
      egress:
        - {}
  YAML
}

# =============================================================================
# DEFAULT DENY — ALL APP NAMESPACES (Cluster-wide)
# =============================================================================
# Applies default-deny to every namespace labeled:
#   scope: apps
#
# To onboard a new app namespace, just add that label to the namespace:
#   kubectl label namespace apps-myapp scope=apps
# =============================================================================

resource "kubectl_manifest" "cilium_default_deny_apps" {
  count = var.enable_cilium_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumClusterwideNetworkPolicy
    metadata:
      name: default-deny-apps
    spec:
      description: "Default deny all traffic in app namespaces (scope=apps)"
      endpointSelector:
        matchLabels:
          k8s:io.kubernetes.pod.namespace.labels.scope: apps
      ingress:
        - {}
      egress:
        - {}
  YAML
}

# =============================================================================
# ALLOW DNS (Cluster-wide)
# =============================================================================
# Without DNS nothing works. This lets every pod reach CoreDNS.
# =============================================================================

resource "kubectl_manifest" "cilium_allow_dns" {
  count = var.enable_cilium_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumClusterwideNetworkPolicy
    metadata:
      name: allow-dns
    spec:
      description: "Allow all pods to resolve DNS via CoreDNS"
      endpointSelector: {}
      egress:
        - toEndpoints:
            - matchLabels:
                k8s:io.kubernetes.pod.namespace: kube-system
                k8s-app: kube-dns
          toPorts:
            - ports:
                - port: "53"
                  protocol: UDP
                - port: "53"
                  protocol: TCP
  YAML
}

# =============================================================================
# ALLOW KUBERNETES API (Cluster-wide)
# =============================================================================
# Pods need API server access for service accounts, workload identity, etc.
# =============================================================================

resource "kubectl_manifest" "cilium_allow_kube_api" {
  count = var.enable_cilium_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumClusterwideNetworkPolicy
    metadata:
      name: allow-kube-apiserver
    spec:
      description: "Allow pods to reach the Kubernetes API server"
      endpointSelector: {}
      egress:
        - toEntities:
            - kube-apiserver
          toPorts:
            - ports:
                - port: "443"
                  protocol: TCP
  YAML
}