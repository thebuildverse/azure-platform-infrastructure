# Azure Platform Infrastructure

Production-grade AKS infrastructure managed entirely through Terraform and Terraform Cloud. Deploys a fully operational Kubernetes platform with GitOps, policy enforcement, secrets management, observability, and automatic DNS/TLS — ready for application workloads on provisioning.

> **Part of a two-repo setup.** This repo provisions the underlying platform. Once deployed, head to [`thebuildverse/demo-app`](https://github.com/thebuildverse/demo-app) to deploy a sample application that exercises the full pipeline — CI/CD via GitHub Actions, image delivery through ACR, GitOps sync with ArgoCD, and secrets pulled from Azure Key Vault via External Secrets Operator.

![Terraform](https://img.shields.io/badge/Terraform-7B42BC?logo=terraform&logoColor=white)
![Azure](https://img.shields.io/badge/Azure-0078D4?logo=microsoft-azure&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?logo=kubernetes&logoColor=white)
![ArgoCD](https://img.shields.io/badge/ArgoCD-EF7B4D?logo=argo&logoColor=white)
![Kyverno](https://img.shields.io/badge/Kyverno-FF9800?logo=kubernetes&logoColor=white)
![Cilium](https://img.shields.io/badge/Cilium-F8C517?logo=cilium&logoColor=black)

---

## What This Deploys

| Component | Description |
|-----------|-------------|
| **AKS Cluster** | Managed Kubernetes with Cilium CNI, Azure AD RBAC, and workload identity |
| **Networking** | VNet with dedicated node/pod subnets, NSGs, service endpoints |
| **Container Registry** | Azure ACR with native AKS pull integration |
| **Observability** | Azure Managed Prometheus + Grafana, Log Analytics |
| **Key Vault** | Secrets management with RBAC and workload identity |
| **Ingress** | NGINX Ingress Controller with automatic TLS via cert-manager ([learn more](https://blog.devgenius.io/externaldns-and-host-based-tls-ingress-in-aks-cluster-edf75fae36f3)) |
| **DNS** | ExternalDNS for automatic DNS record management ([learn more](https://blog.devgenius.io/externaldns-and-host-based-tls-ingress-in-aks-cluster-edf75fae36f3)) |
| **Secrets** | External Secrets Operator syncing from Azure Key Vault via workload identity ([learn more](https://external-secrets.io/latest/provider/azure-key-vault/#mounted-service-account)) |
| **GitOps** | ArgoCD with GitHub SSO ([learn more](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/)) |
| **Policy Engine** | Kyverno for admission control and audit based policy enforcement |
| **Network Security** | Cilium Network Policies for zero-trust networking *(under active development — see note below)* |
| **Identity & Access** | Azure AD groups for AKS, Key Vault, and monitoring RBAC |

---

## End-to-End Architecture

This diagram shows how the infrastructure in **this repo** connecting to the application lifecycle managed in [`demo-app`](https://github.com/thebuildverse/demo-app).

![Platform Architecture](assets/platform-infrastructure-architecture.svg)

> An interactive version of this diagram is also available at [`https://bytiv.github.io/diagrams/platform-architecture.html`](https://bytiv.github.io/diagrams/platform-architecture.html).

---

## Deployment Order

Kubernetes components deploy in optimized phases to balance speed with dependency resolution:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ PHASE 1 (Parallel — no dependencies):                                        │
│   • ingress-nginx (provisions Azure Load Balancer)                           │
│   • kyverno (policy engine)                                                  │
├──────────────────────────────────────────────────────────────────────────────┤
│ PHASE 2 (Parallel — depends on ingress-nginx):                               │
│   • cert-manager (TLS certificates via Let's Encrypt)                        │
│   • external-dns (DNS record management against Azure DNS Zone)              │
├──────────────────────────────────────────────────────────────────────────────┤
│ PHASE 3 (depends on cert-manager):                                           │
│   • argocd (GitOps controller with GitHub SSO)                               │
├──────────────────────────────────────────────────────────────────────────────┤
│ PHASE 4 (depends on argocd):                                                 │
│   • external-secrets (syncs secrets from Azure Key Vault)                    │
│   • kyverno policies (applied after Kyverno is ready)                        │
│   • cilium network policies (applied after all components are ready)         │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### 1. Azure DNS Zone (Manual)

The DNS zone must exist before Terraform runs. ExternalDNS and cert-manager depend on it.

```bash
az group create --name dns-rg --location eastus
az network dns zone create --resource-group dns-rg --name yourdomain.com

# Point your domain registrar's nameservers to Azure's NS records
az network dns zone show --resource-group dns-rg --name yourdomain.com --query nameServers
```

### 2. GitHub OAuth App (for ArgoCD SSO)

ArgoCD uses GitHub OAuth for single sign-on. See the [ArgoCD SSO documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/) for full details.

1. Go to your GitHub Organization → Settings → Developer settings → OAuth Apps
2. Create a new OAuth App:
   - **Application name**: ArgoCD
   - **Homepage URL**: `https://argocd.yourdomain.com`
   - **Authorization callback URL**: `https://argocd.yourdomain.com/api/dex/callback`
3. Save the **Client ID** and generate a **Client Secret**

### 3. Terraform Cloud Setup

This project is designed to run on Terraform Cloud. You can optionally configure SSO between Terraform Cloud and Azure Entra ID — see the [Terraform Cloud SSO guide](https://developer.hashicorp.com/terraform/cloud-docs/users-teams-organizations/single-sign-on/entra-id) for instructions.

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

---

## Configuration

### Step 1: Edit `locals.tf` & `versions.tf`

Update the values in `locals.tf` to match your environment, and configure your Terraform Cloud organization/workspace:

```hcl

# Update organization and workspace names for your environment
terraform {
  cloud {
    organization = "your-terraform-cloud-org"
    workspaces {
      name = "your-workspace"
    }
  }
}

locals {
  # Required: Your environment
  environment = "dev"
  location    = "eastus"
  project     = "myproject"

  # Required: Your domain (must exist in Azure DNS)
  dns = {
    zone_name           = "yourdomain.com"
    zone_resource_group = "dns-rg"
    cert_manager_email  = "admin@yourdomain.com"
  }

  # Required: ArgoCD GitHub SSO
  argocd = {
    github_org   = "your-github-org-name"
    admin_users  = ["your-github-username"]
  }

  # Optional: Security policies
  security = {
    enable_kyverno              = true   # Deploy Kyverno policy engine
    enable_kyverno_policies     = true   # Apply Kyverno policies
    enable_cilium_policies      = false  # See note on Cilium below
    enable_registry_restriction = false  # Restrict container registries
  }
}

```

### Step 2: Deploy

```bash
terraform init
terraform plan
terraform apply
```

---

## Security Features

### Kyverno Policies (Audit Mode)

All Kyverno policies run in **Audit** mode by default — they log violations to policy reports without blocking deployments. This gives you full visibility into compliance posture before switching to enforcement. The one exception is `disallow-latest-tag`, which is set to **Enforce** because allowing untagged images is a deployment reliability risk, not just a security concern.

**Validation Policies** — audit or enforce secure configurations:

| Policy | What It Checks |
|--------|----------------|
| **Disallow Privileged Containers** | Containers with `privileged: true` |
| **Require Run As Non-Root** | Missing `runAsNonRoot: true` |
| **Disallow Host Namespaces** | Use of `hostNetwork`, `hostPID`, `hostIPC` |
| **Disallow Host Ports** | Containers binding to host ports |
| **Drop All Capabilities** | Missing `capabilities.drop: ["ALL"]` |
| **Require Read-Only Root FS** | Missing `readOnlyRootFilesystem: true` |
| **Disallow Latest Tag** | `:latest` or untagged images (**Enforce**) |
| **Require Resource Limits** | Missing CPU/memory limits |
| **Require Resource Requests** | Missing CPU/memory requests |
| **Restrict Image Registries** | Images from non-approved registries (opt-in via `enable_registry_restriction`) |

**Audit Policies** — provide visibility without blocking; these replaced the previous mutation policies to keep policy behavior purely observational:

| Policy | What It Reports |
|--------|-----------------|
| **Audit Security Context Settings** | Pods missing recommended security context (`runAsNonRoot`, `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem`, `drop ALL`) |
| **Audit Resource Requests and Limits** | Pods missing proper CPU/memory requests and limits |

> **Note:** All policies target the `default` and `apps-*` namespaces only. System namespaces are excluded.

### Cilium Network Policies

> ⚠️ **Cilium network policies are under active development.** The policy set is being refined and upgraded. It is recommended to keep `enable_cilium_policies = false` for now until the policies are finalized. The current policies are functional but may change significantly.

When enabled, Cilium policies implement a zero-trust network model:

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

---

## Deploying Applications

Once the infrastructure is running, you're ready to deploy workloads. The [`demo-app`](https://github.com/thebuildverse/demo-app) repo provides a complete working example with CI/CD, GitOps, and secrets integration — it's the recommended starting point.

For any application deployed to this cluster, you need to:

### 1. Use an `apps-` Prefixed Namespace

Kyverno policies scope to `default` and `apps-*` namespaces. ArgoCD can create namespaces automatically if configured with `CreateNamespace=true`.

```bash
kubectl create namespace apps-myapp
```

### 2. Create a CiliumNetworkPolicy (when Cilium policies are enabled)

When Cilium policies are enabled, all traffic is denied by default. You'll need an explicit allow policy for your app:

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
    - fromEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: ingress-nginx
            app.kubernetes.io/name: ingress-nginx
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
  egress:
    - toEntities:
        - world
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
```

### 3. Meet Kyverno Policy Requirements

Your deployments should comply with the active policies. Here's a compliant example:

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

---

## Toggling Policies

Edit `locals.tf` to enable or disable security features:

```hcl
security = {
  enable_kyverno          = false  # Removes Kyverno entirely
  enable_kyverno_policies = false  # Keeps Kyverno but disables policies
  enable_cilium_policies  = false  # Disables network policies
}
```

Then run `terraform apply`.

---

## Outputs

After deployment, useful outputs include:

```bash
terraform output kube_config_command    # kubectl access
terraform output acr_login_server       # Image registry URL
terraform output keyvault_name          # Key Vault for secrets
terraform output argocd_url             # ArgoCD UI
terraform output grafana_url            # Grafana dashboards

# Azure AD Groups
terraform output aks_admins_group
terraform output keyvault_admins_group
terraform output keyvault_readers_group
terraform output monitoring_admins_group
terraform output monitoring_readers_group
```

---

## Resource Allocation

Optimized for 2 nodes of `Standard_D2as_v4` (2 vCPU, 8GB RAM each):

| Component | CPU Request | Memory Request |
|-----------|-------------|----------------|
| ingress-nginx | 100m | 128Mi |
| cert-manager | 100m | 160Mi |
| external-dns | 25m | 64Mi |
| argocd (all) | 250m | 640Mi |
| external-secrets | 45m | 128Mi |
| kyverno (all) | 250m | 640Mi |
| **Total** | **~770m** | **~1.7GB** |

This leaves approximately 3.2 vCPU and 14GB RAM for your application workloads.

---

## Maintenance

### Switching Kyverno from Audit to Enforce

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
GROUP_ID=$(az ad group show --group "keyvault-admins-platform-dev-eus" --query id -o tsv)
az ad group member add --group $GROUP_ID --member-id <USER_OBJECT_ID>
```

### Rotating Secrets

Update secrets in Key Vault; External Secrets Operator syncs automatically (default: 1 hour).

---

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

### Deployments Flagged by Kyverno

1. Check policy reports:
   ```bash
   kubectl get policyreport -A
   ```
2. Check which policy flagged a violation:
   ```bash
   kubectl get events --field-selector reason=PolicyViolation
   ```
3. Policies are in audit mode by default — they report but don't block. If deployments are being rejected, verify no one has changed a policy to enforce mode.

---

## References & Further Reading

| Topic | Link |
|-------|------|
| Deploy Azure Infrastructure using Terraform Cloud | [Tutorial](https://dev.to/playfulprogramming/deploy-azure-infrastructure-using-terraform-cloud-3j9d) |
| Terraform Cloud SSO with Azure Entra ID | [HashiCorp Docs](https://developer.hashicorp.com/terraform/cloud-docs/users-teams-organizations/single-sign-on/entra-id) |
| External Secrets Operator with Azure Key Vault | [ESO Documentation](https://external-secrets.io/latest/provider/azure-key-vault/#mounted-service-account) |
| ExternalDNS & Host-Based TLS Ingress in AKS | [DevGenius Guide](https://blog.devgenius.io/externaldns-and-host-based-tls-ingress-in-aks-cluster-edf75fae36f3) |
| ArgoCD SSO & User Management | [ArgoCD Docs](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/) |

---

## Related Repository

| Repo | Description |
|------|-------------|
| [`thebuildverse/demo-app`](https://github.com/thebuildverse/demo-app) | Demo application with GitHub Actions CI/CD, ArgoCD GitOps delivery, and External Secrets integration — deploys onto the platform provisioned by this repo |
