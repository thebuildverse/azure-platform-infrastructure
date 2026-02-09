# =============================================================================
# CILIUM NETWORK POLICIES
# =============================================================================
# Cilium provides fine-grained network security at Layer 3/4 and Layer 7.
# These policies implement a zero-trust network model:
# 1. Default deny all traffic
# 2. Explicitly allow only required communication paths
#
# Toggle: Set enable_cilium_policies = false in locals.tf to disable all policies
#
# IMPORTANT: When deploying applications, you'll need to create CiliumNetworkPolicies
# to allow traffic. See the example at the end of this file.
# =============================================================================

# =============================================================================
# DEFAULT DENY POLICIES
# =============================================================================
# These policies block ALL traffic by default in each namespace.
# Think of it as a firewall that blocks everything until you create allow rules.
# Without explicit allow rules, pods cannot:
# - Receive any incoming traffic (ingress)
# - Send any outgoing traffic (egress)
# =============================================================================

# Default deny for ingress-nginx namespace
resource "kubectl_manifest" "cilium_default_deny_ingress_nginx" {
  count = var.enable_cilium_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumNetworkPolicy
    metadata:
      name: default-deny
      namespace: ingress-nginx
    spec:
      description: "Default deny all traffic in ingress-nginx namespace"
      endpointSelector: {}  # Matches all pods in namespace
      ingress:
        - {}  # Empty rule = deny all ingress
      egress:
        - {}  # Empty rule = deny all egress
  YAML

  depends_on = [helm_release.ingress_nginx]
}

# Default deny for cert-manager namespace
resource "kubectl_manifest" "cilium_default_deny_cert_manager" {
  count = var.enable_cilium_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumNetworkPolicy
    metadata:
      name: default-deny
      namespace: cert-manager
    spec:
      description: "Default deny all traffic in cert-manager namespace"
      endpointSelector: {}
      ingress:
        - {}
      egress:
        - {}
  YAML

  depends_on = [helm_release.cert_manager]
}

# Default deny for external-dns namespace
resource "kubectl_manifest" "cilium_default_deny_external_dns" {
  count = var.enable_cilium_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumNetworkPolicy
    metadata:
      name: default-deny
      namespace: external-dns
    spec:
      description: "Default deny all traffic in external-dns namespace"
      endpointSelector: {}
      ingress:
        - {}
      egress:
        - {}
  YAML

  depends_on = [helm_release.external_dns]
}

# Default deny for external-secrets namespace
resource "kubectl_manifest" "cilium_default_deny_external_secrets" {
  count = var.enable_cilium_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumNetworkPolicy
    metadata:
      name: default-deny
      namespace: external-secrets
    spec:
      description: "Default deny all traffic in external-secrets namespace"
      endpointSelector: {}
      ingress:
        - {}
      egress:
        - {}
  YAML

  depends_on = [helm_release.external_secrets]
}

# Default deny for argocd namespace
resource "kubectl_manifest" "cilium_default_deny_argocd" {
  count = var.enable_cilium_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumNetworkPolicy
    metadata:
      name: default-deny
      namespace: argocd
    spec:
      description: "Default deny all traffic in argocd namespace"
      endpointSelector: {}
      ingress:
        - {}
      egress:
        - {}
  YAML

  depends_on = [helm_release.argocd]
}

# Default deny for kyverno namespace
resource "kubectl_manifest" "cilium_default_deny_kyverno" {
  count = var.enable_cilium_policies && var.enable_kyverno ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumNetworkPolicy
    metadata:
      name: default-deny
      namespace: kyverno
    spec:
      description: "Default deny all traffic in kyverno namespace"
      endpointSelector: {}
      ingress:
        - {}
      egress:
        - {}
  YAML

  depends_on = [helm_release.kyverno]
}

# =============================================================================
# ALLOW DNS POLICY (CLUSTER-WIDE)
# =============================================================================
# Effect: Allows all pods to reach kube-dns/CoreDNS for name resolution
# Why: Without DNS, pods can't resolve service names (e.g., "argocd-server")
#      and basically nothing works. This is essential infrastructure.
# Scope: Applies to all namespaces via CiliumClusterwideNetworkPolicy
# =============================================================================

resource "kubectl_manifest" "cilium_allow_dns" {
  count = var.enable_cilium_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumClusterwideNetworkPolicy
    metadata:
      name: allow-dns
    spec:
      description: "Allow all pods to access DNS (kube-dns)"
      endpointSelector: {}  # Matches all pods
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

  depends_on = [helm_release.ingress_nginx]
}

# =============================================================================
# ALLOW KUBERNETES API ACCESS
# =============================================================================
# Effect: Allows pods to communicate with the Kubernetes API server
# Why: Many components need API access:
#      - Controllers (watch resources)
#      - Service account token validation
#      - Workload identity (OIDC token exchange)
# Uses toEntities: kube-apiserver to match the API server
# =============================================================================

resource "kubectl_manifest" "cilium_allow_kube_api" {
  count = var.enable_cilium_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumClusterwideNetworkPolicy
    metadata:
      name: allow-kube-apiserver
    spec:
      description: "Allow pods to communicate with Kubernetes API server"
      endpointSelector: {}
      egress:
        - toEntities:
            - kube-apiserver
          toPorts:
            - ports:
                - port: "443"
                  protocol: TCP
  YAML

  depends_on = [helm_release.ingress_nginx]
}

# =============================================================================
# INGRESS-NGINX POLICIES
# =============================================================================
# Effect: Allows ingress-nginx to receive external traffic and route to backends
# Why: ingress-nginx is the entry point for all external HTTP(S) traffic
# Allows:
#      - Ingress: External traffic (world) on ports 80, 443
#      - Egress: Traffic to any pod in the cluster (for routing)
#      - Egress: Traffic to cert-manager for TLS challenges
# =============================================================================

resource "kubectl_manifest" "cilium_ingress_nginx_allow" {
  count = var.enable_cilium_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumNetworkPolicy
    metadata:
      name: allow-ingress-controller
      namespace: ingress-nginx
    spec:
      description: "Allow ingress-nginx to receive external traffic and route to backends"
      endpointSelector:
        matchLabels:
          app.kubernetes.io/name: ingress-nginx
          app.kubernetes.io/component: controller
      ingress:
        # Allow external traffic (from internet via load balancer)
        - fromEntities:
            - world
            - cluster
          toPorts:
            - ports:
                - port: "80"
                  protocol: TCP
                - port: "443"
                  protocol: TCP
        # Allow health checks from Azure load balancer
        - fromEntities:
            - world
          toPorts:
            - ports:
                - port: "10254"
                  protocol: TCP
      egress:
        # Allow routing to any pod in the cluster
        - toEntities:
            - cluster
        # Allow external traffic for webhooks, etc
        - toEntities:
            - world
          toPorts:
            - ports:
                - port: "443"
                  protocol: TCP
  YAML

  depends_on = [helm_release.ingress_nginx]
}

# =============================================================================
# CERT-MANAGER POLICIES
# =============================================================================
# Effect: Allows cert-manager to manage TLS certificates
# Why: cert-manager needs to:
#      - Talk to Let's Encrypt (ACME) servers for certificate issuance
#      - Create/update Kubernetes secrets for certificates
#      - Receive webhook calls for validation
# Allows:
#      - Egress: HTTPS to Let's Encrypt (acme-v02.api.letsencrypt.org)
#      - Egress: DNS for name resolution (already covered by allow-dns)
#      - Ingress: Webhook traffic from API server
# =============================================================================

resource "kubectl_manifest" "cilium_cert_manager_allow" {
  count = var.enable_cilium_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumNetworkPolicy
    metadata:
      name: allow-cert-manager
      namespace: cert-manager
    spec:
      description: "Allow cert-manager to communicate with Let's Encrypt and API server"
      endpointSelector:
        matchLabels:
          app.kubernetes.io/instance: cert-manager
      ingress:
        # Allow webhook calls from API server
        - fromEntities:
            - kube-apiserver
          toPorts:
            - ports:
                - port: "10250"
                  protocol: TCP
        # Allow internal cluster traffic
        - fromEntities:
            - cluster
      egress:
        # Allow HTTPS to Let's Encrypt and other ACME providers
        - toEntities:
            - world
          toPorts:
            - ports:
                - port: "443"
                  protocol: TCP
        # Allow HTTP for ACME HTTP-01 challenges
        - toEntities:
            - world
          toPorts:
            - ports:
                - port: "80"
                  protocol: TCP
  YAML

  depends_on = [helm_release.cert_manager]
}

# =============================================================================
# EXTERNAL-DNS POLICIES
# =============================================================================
# Effect: Allows external-dns to manage DNS records in Azure
# Why: external-dns needs to:
#      - Watch Ingress/Service resources (via API server)
#      - Update Azure DNS zone records (via Azure APIs)
# Allows:
#      - Egress: HTTPS to Azure management endpoints (management.azure.com)
#      - Egress: HTTPS for Azure AD authentication
# =============================================================================

resource "kubectl_manifest" "cilium_external_dns_allow" {
  count = var.enable_cilium_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumNetworkPolicy
    metadata:
      name: allow-external-dns
      namespace: external-dns
    spec:
      description: "Allow external-dns to communicate with Azure DNS APIs"
      endpointSelector:
        matchLabels:
          app.kubernetes.io/name: external-dns
      egress:
        # Allow HTTPS to Azure APIs
        - toEntities:
            - world
          toPorts:
            - ports:
                - port: "443"
                  protocol: TCP
  YAML

  depends_on = [helm_release.external_dns]
}

# =============================================================================
# EXTERNAL-SECRETS POLICIES
# =============================================================================
# Effect: Allows external-secrets to sync secrets from Azure Key Vault
# Why: external-secrets needs to:
#      - Connect to Azure Key Vault to read secrets
#      - Authenticate via Azure AD (workload identity)
#      - Create/update Kubernetes secrets
# Allows:
#      - Egress: HTTPS to Azure Key Vault (*.vault.azure.net)
#      - Egress: HTTPS for Azure AD authentication
#      - Ingress: Webhook calls from API server
# =============================================================================

resource "kubectl_manifest" "cilium_external_secrets_allow" {
  count = var.enable_cilium_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumNetworkPolicy
    metadata:
      name: allow-external-secrets
      namespace: external-secrets
    spec:
      description: "Allow external-secrets to communicate with Azure Key Vault"
      endpointSelector:
        matchLabels:
          app.kubernetes.io/name: external-secrets
      ingress:
        # Allow webhook calls from API server
        - fromEntities:
            - kube-apiserver
          toPorts:
            - ports:
                - port: "10250"
                  protocol: TCP
        # Allow cluster internal traffic
        - fromEntities:
            - cluster
      egress:
        # Allow HTTPS to Azure Key Vault and Azure AD
        - toEntities:
            - world
          toPorts:
            - ports:
                - port: "443"
                  protocol: TCP
  YAML

  depends_on = [helm_release.external_secrets]
}

# =============================================================================
# ARGOCD POLICIES
# =============================================================================
# Effect: Allows ArgoCD components to function (GitOps, SSO, deployments)
# Why: ArgoCD needs to:
#      - Pull manifests from GitHub repositories
#      - Authenticate users via GitHub OAuth (Dex)
#      - Deploy resources to the cluster
#      - Serve the web UI via ingress
# Allows:
#      - Ingress: Traffic from ingress-nginx (web UI)
#      - Egress: HTTPS to GitHub (git pulls, OAuth)
#      - Egress: Cluster traffic (deploy to namespaces)
# =============================================================================

resource "kubectl_manifest" "cilium_argocd_allow" {
  count = var.enable_cilium_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumNetworkPolicy
    metadata:
      name: allow-argocd
      namespace: argocd
    spec:
      description: "Allow ArgoCD to function (Git sync, OAuth, deployments)"
      endpointSelector: {}  # All pods in argocd namespace
      ingress:
        # Allow traffic from ingress-nginx
        - fromEndpoints:
            - matchLabels:
                k8s:io.kubernetes.pod.namespace: ingress-nginx
                app.kubernetes.io/name: ingress-nginx
          toPorts:
            - ports:
                - port: "8080"
                  protocol: TCP
                - port: "8083"
                  protocol: TCP
                - port: "5556"
                  protocol: TCP
        # Allow internal ArgoCD component communication
        - fromEndpoints:
            - matchLabels:
                k8s:io.kubernetes.pod.namespace: argocd
      egress:
        # Allow HTTPS to GitHub and other external services
        - toEntities:
            - world
          toPorts:
            - ports:
                - port: "443"
                  protocol: TCP
                - port: "22"
                  protocol: TCP
        # Allow internal cluster communication (for deployments)
        - toEntities:
            - cluster
  YAML

  depends_on = [helm_release.argocd]
}

# =============================================================================
# KYVERNO POLICIES
# =============================================================================
# Effect: Allows Kyverno admission controller to function
# Why: Kyverno needs to:
#      - Receive webhook calls from API server for policy enforcement
#      - Access API server to watch policies and resources
# Allows:
#      - Ingress: Webhook calls from API server on port 443
#      - Egress: Cluster traffic for API access
# =============================================================================

resource "kubectl_manifest" "cilium_kyverno_allow" {
  count = var.enable_cilium_policies && var.enable_kyverno ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumNetworkPolicy
    metadata:
      name: allow-kyverno
      namespace: kyverno
    spec:
      description: "Allow Kyverno admission controller to function"
      endpointSelector: {}  # All pods in kyverno namespace
      ingress:
        # Allow webhook calls from API server
        - fromEntities:
            - kube-apiserver
          toPorts:
            - ports:
                - port: "443"
                  protocol: TCP
                - port: "9443"
                  protocol: TCP
        # Allow internal Kyverno component communication
        - fromEndpoints:
            - matchLabels:
                k8s:io.kubernetes.pod.namespace: kyverno
      egress:
        # Allow cluster communication for API access
        - toEntities:
            - cluster
  YAML

  depends_on = [helm_release.kyverno]
}

# =============================================================================
# SYSTEM NAMESPACE PROTECTION
# =============================================================================
# Effect: Blocks non-system pods from communicating with kube-system
# Why: kube-system contains critical components:
#      - etcd (cluster state)
#      - kube-proxy
#      - CoreDNS (we allow this separately)
#      - Azure system pods
# Application pods should never need direct access to these.
# Exception: DNS access is allowed via the allow-dns policy above
# =============================================================================

resource "kubectl_manifest" "cilium_protect_kube_system" {
  count = var.enable_cilium_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumClusterwideNetworkPolicy
    metadata:
      name: protect-kube-system
    spec:
      description: "Protect kube-system from unauthorized access"
      endpointSelector:
        matchLabels:
          k8s:io.kubernetes.pod.namespace: kube-system
      ingress:
        # Only allow traffic from system namespaces and DNS queries
        - fromEndpoints:
            - matchExpressions:
                - key: k8s:io.kubernetes.pod.namespace
                  operator: In
                  values:
                    - kube-system
                    - kube-public
                    - kube-node-lease
                    - ingress-nginx
                    - cert-manager
                    - external-dns
                    - external-secrets
                    - argocd
                    - kyverno
        # Allow DNS queries from all pods (matches the allow-dns policy)
        - fromEntities:
            - cluster
          toPorts:
            - ports:
                - port: "53"
                  protocol: UDP
                - port: "53"
                  protocol: TCP
  YAML

  depends_on = [helm_release.ingress_nginx]
}

# =============================================================================
# APPLICATION NAMESPACE TEMPLATE
# =============================================================================
# This is a TEMPLATE showing how to create policies for your application
# namespaces. You'll need to create similar policies for each app namespace.
#
# To deploy an application that can receive traffic via ingress:
#
# 1. Create a namespace with the "apps-" prefix:
#    kubectl create namespace apps-myapp
#
# 2. Apply a CiliumNetworkPolicy like this in your app namespace:
#
# apiVersion: cilium.io/v2
# kind: CiliumNetworkPolicy
# metadata:
#   name: allow-myapp
#   namespace: apps-myapp
# spec:
#   description: "Allow traffic for myapp"
#   endpointSelector:
#     matchLabels:
#       app: myapp
#   ingress:
#     # Allow traffic from ingress-nginx
#     - fromEndpoints:
#         - matchLabels:
#             k8s:io.kubernetes.pod.namespace: ingress-nginx
#             app.kubernetes.io/name: ingress-nginx
#       toPorts:
#         - ports:
#             - port: "8080"  # Your app's port
#               protocol: TCP
#   egress:
#     # Allow outbound HTTPS (for APIs, etc.)
#     - toEntities:
#         - world
#       toPorts:
#         - ports:
#             - port: "443"
#               protocol: TCP
#     # Allow access to other services in the same namespace
#     - toEndpoints:
#         - matchLabels:
#             k8s:io.kubernetes.pod.namespace: apps-myapp
#
# =============================================================================
