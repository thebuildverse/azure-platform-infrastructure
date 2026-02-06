# Azure Kubernetes Platform

Production-grade AKS infrastructure with GitOps tooling, policy enforcement, network security, and observability.

## What This Deploys

| Component | Description |
|-----------|-------------|
| **AKS Cluster** | Managed Kubernetes with Cilium CNI, Azure AD RBAC, workload identity |
| **Networking** | VNet with dedicated node/pod subnets, NSGs, service endpoints |
| **Container Registry** | Azure ACR with AKS pull integration |
| **Observability** | Azure Managed Prometheus, Grafana, Log Analytics |
| **Key Vault** | Secrets management with RBAC and workload identity |
| **Ingress** | NGINX Ingress Controller with automatic TLS via cert-manager |
| **DNS** | External-DNS for automatic DNS record management |
| **Secrets** | External Secrets Operator syncing from Azure Key Vault |
| **GitOps** | ArgoCD with GitHub SSO integration |
| **Policy Engine** | Kyverno for admission control and policy enforcement |
| **Network Security** | Cilium Network Policies for zero-trust networking |

## Prerequisites

Before deploying, you must complete these steps:

### 1. Azure Resources (Manual)

```bash
# Create DNS Zone resource group and zone
az group create --name rg-dns --location eastus
az network dns zone create --resource-group rg-dns --name yourdomain.com

# Update your domain registrar's nameservers to Azure's NS records
az network dns zone show --resource-group rg-dns --name yourdomain.com --query nameServers
```

### 2. GitHub OAuth App (For ArgoCD SSO)

1. Go to your GitHub Organization → Settings → Developer settings → OAuth Apps
2. Create new OAuth App:
   - **Application name**: ArgoCD
   - **Homepage URL**: `https://argocd.yourdomain.com`
   - **Authorization callback URL**: `https://argocd.yourdomain.com/api/dex/callback`
3. Save the **Client ID** and generate a **Client Secret**

### 3. Terraform Cloud Setup

1. Create a workspace in Terraform Cloud
2. Configure these workspace variables:

| Variable | Type | Description |
|----------|------|-------------|
| `arm_client_id` | Environment | Service Principal App ID |
| `arm_client_secret` | Environment (Sensitive) | Service Principal Password |
| `arm_tenant_id` | Environment | Azure AD Tenant ID |
| `arm_subscription_id` | Environment | Azure Subscription ID |
| `argocd_github_client_id` | Terraform Variable | GitHub OAuth Client ID |
| `argocd_github_client_secret` | Terraform Variable (Sensitive) | GitHub OAuth Client Secret |

## Configuration

### Step 1: Edit `locals.tf` & `versions.tf`

Update the values in `locals.tf` as well as `versions.tf` Terraform cloud organization and workspace:

```hcl
locals {
  # Required: Your environment
  environment = "dev"
  location    = "eastus"
  project     = "myproject"

  # Required: Your domain (must exist in Azure DNS)
  dns = {
    zone_name           = "yourdomain.com"
    zone_resource_group = "rg-dns"
    cert_manager_email  = "admin@yourdomain.com"
  }

  # Required: ArgoCD GitHub SSO
  argocd = {
    github_org   = "your-github-org"
    admin_users  = ["your-github-username"]
  }

  # Optional: Security policies (enabled by default)
  security = {
    enable_kyverno              = true   # Deploy Kyverno policy engine
    enable_kyverno_policies     = true   # Apply Kyverno policies
    enable_cilium_policies      = true   # Apply Cilium network policies
    enable_registry_restriction = false  # Restrict container registries
  }
}

# versions.tf
terraform { 
  cloud { 
    organization = "your-terraformCloud-org" 
    workspaces { 
      name = "your-workspace" 
    } 
  } 
}
```

### Step 2: Deploy

```bash
# Initialize and apply
terraform init
terraform plan
terraform apply
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Azure Subscription                           │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────┐    ┌─────────────────────────────────┐ │
│  │   rg-platform-dev-eus   │    │       rg-shared-eus             │ │
│  │                         │    │                                 │ │
│  │  ┌─────────────────┐    │    │  ┌──────────┐  ┌─────────────┐  │ │
│  │  │   AKS Cluster   │    │    │  │   ACR    │  │  Key Vault  │  │ │
│  │  │  ┌───────────┐  │    │    │  │          │  │   (RBAC)    │  │ │
│  │  │  │ Node Pool │  │    │    │  └──────────┘  └─────────────┘  │ │
│  │  │  └───────────┘  │    │    │                                 │ │
│  │  └────────┬────────┘    │    └─────────────────────────────────┘ │
│  │           │             │                                        │
│  │  ┌────────┴────────┐    │    ┌─────────────────────────────────┐ │
│  │  │      VNet       │    │    │         rg-dns                  │ │
│  │  │ ┌─────┐ ┌─────┐ │    │    │  ┌──────────────────────────┐   │ │
│  │  │ │Node │ │ Pod │ │    │    │  │    DNS Zone              │   │ │
│  │  │ │Snet │ │Snet │ │    │    │  │  (managed separately)    │   │ │
│  │  │ └─────┘ └─────┘ │    │    │  └──────────────────────────┘   │ │
│  │  └─────────────────┘    │    └─────────────────────────────────┘ │
│  │                         │                                        │
│  │  ┌─────────────────┐    │                                        │
│  │  │   Monitoring    │    │                                        │
│  │  │ ┌─────┐ ┌─────┐ │    │                                        │
│  │  │ │Prom │ │Graf │ │    │                                        │
│  │  │ └─────┘ └─────┘ │    │                                        │
│  │  └─────────────────┘    │                                        │
│  └─────────────────────────┘                                        │
└─────────────────────────────────────────────────────────────────────┘
```

## Deployment Order

The Kubernetes components deploy in optimized phases to balance speed with dependencies:

```
┌─────────────────────────────────────────────────────────────────────────┐
│ PHASE 1 (Parallel - no dependencies):                                   │
│   - ingress-nginx (provisions Azure Load Balancer)                      │
│   - kyverno (policy engine)                                             │
├─────────────────────────────────────────────────────────────────────────┤
│ PHASE 2 (Parallel - depends on ingress-nginx):                          │
│   - cert-manager (TLS certificates)                                     │
│   - external-dns (DNS record management)                                │
├─────────────────────────────────────────────────────────────────────────┤
│ PHASE 3 (depends on cert-manager):                                      │
│   - argocd (GitOps)                                                     │
├─────────────────────────────────────────────────────────────────────────┤
│ PHASE 4 (depends on argocd):                                            │
│   - external-secrets (secret sync)                                      │
│   - cilium network policies (applied after all components ready)        │
│   - kyverno policies (applied after Kyverno ready)                      │
└─────────────────────────────────────────────────────────────────────────┘
```

## Security Features

### Kyverno Policies (Audit Mode by Default)

| Policy | Effect |
|--------|--------|
| **Disallow Privileged Containers** | Blocks containers with `privileged: true` |
| **Require Run As Non-Root** | Requires `runAsNonRoot: true` |
| **Disallow Host Namespaces** | Blocks `hostNetwork`, `hostPID`, `hostIPC` |
| **Disallow Host Ports** | Prevents binding to host ports |
| **Drop All Capabilities** | Requires `capabilities.drop: ["ALL"]` |
| **Require Read-Only Root FS** | Requires `readOnlyRootFilesystem: true` |
| **Disallow Latest Tag** | Blocks `:latest` image tags |
| **Require Resource Limits** | Requires CPU/memory limits |
| **Require Resource Requests** | Requires CPU/memory requests |
| **Add Default Security Context** | Auto-adds secure defaults (mutation) |
| **Add Default Resources** | Auto-adds resource limits (mutation) |

**Note:** Policies apply to `default` and `apps-*` namespaces. System namespaces are excluded.

### Cilium Network Policies

| Policy | Effect |
|--------|--------|
| **Default Deny** | Blocks all traffic unless explicitly allowed |
| **Allow DNS** | Permits DNS resolution for all pods |
| **Allow Kube API** | Permits API server communication |
| **Namespace Isolation** | Each namespace is isolated by default |
| **System Protection** | Blocks non-system access to kube-system |
| **Component Policies** | Allow rules for ingress, cert-manager, external-dns, argocd, external-secrets |

### Azure AD Groups

| Group | Access |
|-------|--------|
| `aks-admins-{prefix}` | Full AKS cluster admin |
| `aks-writers-{prefix}` | AKS write access |
| `aks-readers-{prefix}` | AKS read-only access |
| `keyvault-admins-{prefix}` | Key Vault secret management |
| `keyvault-readers-{prefix}` | Key Vault read-only |
| `monitoring-admins-{prefix}` | Grafana admin + monitoring config |
| `monitoring-readers-{prefix}` | Grafana viewer |

## Deploying Applications

When deploying applications to this cluster, you need to:

### 1. Create a Namespace with `apps-` Prefix

```bash
kubectl create namespace apps-myapp
```

### 2. Create a CiliumNetworkPolicy for Your App

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-myapp
  namespace: apps-myapp
spec:
  description: "Allow traffic for myapp"
  endpointSelector:
    matchLabels:
      app: myapp
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
  egress:
    # Allow outbound HTTPS (for APIs, etc.)
    - toEntities:
        - world
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
```

### 3. Ensure Your Deployment Meets Kyverno Policies

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: apps-myapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: myregistry.azurecr.io/myapp:v1.0.0  # Explicit tag, not :latest
          ports:
            - containerPort: 8080
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            readOnlyRootFilesystem: true
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
```

## Disabling Policies

To disable security policies (e.g., for debugging), edit `locals.tf`:

```hcl
security = {
  enable_kyverno          = false  # Disables Kyverno entirely
  enable_kyverno_policies = false  # Keeps Kyverno but disables policies
  enable_cilium_policies  = false  # Disables network policies
}
```

Then run `terraform apply`.

## Outputs

After deployment, key outputs include:

```bash
terraform output keyvault_name          # For storing secrets
terraform output acr_login_server       # For pushing images
terraform output argocd_url             # ArgoCD UI
terraform output grafana_url            # Grafana dashboards
terraform output kube_config_command    # kubectl configuration command

# Azure AD Groups
terraform output keyvault_admins_group
terraform output keyvault_readers_group
terraform output monitoring_admins_group
terraform output monitoring_readers_group
terraform output aks_admins_group
```

## Resource Allocation

This deployment is optimized for 2 nodes of `Standard_D2as_v4` (2 vCPU, 8GB RAM each):

| Component | CPU Request | Memory Request |
|-----------|-------------|----------------|
| ingress-nginx | 100m | 128Mi |
| cert-manager | 100m | 160Mi |
| external-dns | 25m | 64Mi |
| argocd (all) | 250m | 640Mi |
| external-secrets | 45m | 128Mi |
| kyverno (all) | 250m | 640Mi |
| **Total** | **~770m** | **~1.7GB** |

This leaves approximately 3.2 vCPU and 14GB RAM for your applications.

## Maintenance

### Switching Kyverno from Audit to Enforce Mode

Edit the policies in `kubernetes/kyverno-policies.tf` and change:
```hcl
validationFailureAction: Audit
```
to:
```hcl
validationFailureAction: Enforce
```

### Adding Users to Azure AD Groups

```bash
# Get group ID
GROUP_ID=$(az ad group show --group "keyvault-admins-platform-dev-eus" --query id -o tsv)

# Add user
az ad group member add --group $GROUP_ID --member-id <USER_OBJECT_ID>
```

### Rotating Secrets

Update secrets in Key Vault; External Secrets Operator syncs automatically (default: 1 hour).

## Troubleshooting

### Pods Can't Communicate

1. Check if Cilium policies are blocking traffic:
   ```bash
   kubectl get ciliumnetworkpolicies -A
   ```

2. Check Cilium agent logs:
   ```bash
   kubectl logs -n kube-system -l k8s-app=cilium
   ```

3. Temporarily disable policies:
   ```hcl
   enable_cilium_policies = false
   ```

### Deployments Blocked by Kyverno

1. Check policy reports:
   ```bash
   kubectl get policyreport -A
   ```

2. Check which policy is blocking:
   ```bash
   kubectl get events --field-selector reason=PolicyViolation
   ```

3. Policies are in audit mode by default, so they shouldn't block. If they do, check if someone changed to enforce mode.

### Kyverno Webhook Timeout

If API server is slow to respond due to Kyverno webhook:
```bash
kubectl delete validatingwebhookconfiguration kyverno-resource-validating-webhook-cfg
kubectl delete mutatingwebhookconfiguration kyverno-resource-mutating-webhook-cfg
# Then redeploy with terraform apply
```
