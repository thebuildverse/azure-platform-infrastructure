# =============================================================================
# KYVERNO POLICIES
# =============================================================================
# This file contains all Kyverno policies for cluster security and resource
# management. Policies are in AUDIT mode by default - they log violations but
# don't block deployments. Change validationFailureAction to "Enforce" when ready.
#
# Policy Categories:
# 1. Security Policies - Audit secure container configurations
# 2. Resource Management - Ensure proper resource allocation
#
# Toggle: Set enable_kyverno_policies = false in locals.tf to disable all policies
# =============================================================================

# =============================================================================
# SECURITY POLICY: DISALLOW PRIVILEGED CONTAINERS
# =============================================================================
# Effect: Prevents containers from running with privileged: true
# Why: Privileged containers have full access to the host, including:
#      - All devices on the host
#      - Can load kernel modules
#      - Can modify host network settings
#      - Essentially root access to the node
# Impact: Blocks deployments with securityContext.privileged: true
resource "kubectl_manifest" "policy_disallow_privileged" {
  count = var.enable_kyverno_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: disallow-privileged-containers
      annotations:
        policies.kyverno.io/title: Disallow Privileged Containers
        policies.kyverno.io/category: Pod Security
        policies.kyverno.io/severity: high
        policies.kyverno.io/description: >-
          Privileged containers have full access to the host. This policy
          prevents pods from running privileged containers.
    spec:
      validationFailureAction: Audit
      background: true
      rules:
        - name: privileged-containers
          match:
            any:
              - resources:
                  kinds:
                    - Pod
                  namespaces:
                    - "default"
                    - "apps-*"
          validate:
            message: "Privileged containers are not allowed."
            pattern:
              spec:
                containers:
                  - securityContext:
                      privileged: "false"
        - name: privileged-init-containers
          match:
            any:
              - resources:
                  kinds:
                    - Pod
                  namespaces:
                    - "default"
                    - "apps-*"
          validate:
            message: "Privileged init containers are not allowed."
            pattern:
              spec:
                =(initContainers):
                  - securityContext:
                      privileged: "false"
  YAML

  depends_on = [time_sleep.wait_for_kyverno]
}

# =============================================================================
# SECURITY POLICY: REQUIRE RUN AS NON-ROOT
# =============================================================================
# Effect: Requires containers to run as a non-root user
# Why: Running as root inside a container increases attack surface:
#      - If an attacker escapes the container, they're root on the host
#      - Can modify system files within the container
#      - Can bind to privileged ports
# Impact: Blocks pods without runAsNonRoot: true or explicit runAsUser > 0
resource "kubectl_manifest" "policy_require_run_as_nonroot" {
  count = var.enable_kyverno_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: require-run-as-nonroot
      annotations:
        policies.kyverno.io/title: Require Run As Non-Root
        policies.kyverno.io/category: Pod Security
        policies.kyverno.io/severity: medium
        policies.kyverno.io/description: >-
          Containers must run as a non-root user to reduce the risk of
          container escape and privilege escalation attacks.
    spec:
      validationFailureAction: Audit
      background: true
      rules:
        - name: run-as-non-root
          match:
            any:
              - resources:
                  kinds:
                    - Pod
                  namespaces:
                    - "default"
                    - "apps-*"
          validate:
            message: "Containers must run as non-root. Set securityContext.runAsNonRoot to true."
            pattern:
              spec:
                containers:
                  - securityContext:
                      runAsNonRoot: true
  YAML

  depends_on = [time_sleep.wait_for_kyverno]
}

# =============================================================================
# SECURITY POLICY: DISALLOW HOST NAMESPACES
# =============================================================================
# Effect: Prevents pods from using host namespaces (hostNetwork, hostPID, hostIPC)
# Why: Host namespaces break container isolation:
#      - hostNetwork: Pod uses host's network stack, can sniff all traffic
#      - hostPID: Pod can see all processes on the host, potential for attacks
#      - hostIPC: Pod can communicate with host processes via shared memory
# Impact: Blocks pods with any of these set to true
resource "kubectl_manifest" "policy_disallow_host_namespaces" {
  count = var.enable_kyverno_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: disallow-host-namespaces
      annotations:
        policies.kyverno.io/title: Disallow Host Namespaces
        policies.kyverno.io/category: Pod Security
        policies.kyverno.io/severity: high
        policies.kyverno.io/description: >-
          Host namespaces (hostNetwork, hostPID, hostIPC) allow pods to access
          host resources and should be disallowed for security.
    spec:
      validationFailureAction: Audit
      background: true
      rules:
        - name: host-namespaces
          match:
            any:
              - resources:
                  kinds:
                    - Pod
                  namespaces:
                    - "default"
                    - "apps-*"
          validate:
            message: "Host namespaces (hostNetwork, hostPID, hostIPC) are not allowed."
            pattern:
              spec:
                =(hostNetwork): false
                =(hostPID): false
                =(hostIPC): false
  YAML

  depends_on = [time_sleep.wait_for_kyverno]
}

# =============================================================================
# SECURITY POLICY: DISALLOW HOST PORTS
# =============================================================================
# Effect: Prevents containers from binding to host ports
# Why: Host ports bypass the Kubernetes service abstraction:
#      - Can conflict with other pods or system services
#      - Bypasses ingress controller and network policies
#      - Makes pods dependent on specific node placement
# Impact: Blocks pods with hostPort specified in container ports
resource "kubectl_manifest" "policy_disallow_host_ports" {
  count = var.enable_kyverno_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: disallow-host-ports
      annotations:
        policies.kyverno.io/title: Disallow Host Ports
        policies.kyverno.io/category: Pod Security
        policies.kyverno.io/severity: medium
        policies.kyverno.io/description: >-
          Host ports allow pods to bind directly to node ports, bypassing
          Kubernetes networking. This should be avoided for security.
    spec:
      validationFailureAction: Audit
      background: true
      rules:
        - name: host-ports
          match:
            any:
              - resources:
                  kinds:
                    - Pod
                  namespaces:
                    - "default"
                    - "apps-*"
          validate:
            message: "Host ports are not allowed. Use Services and Ingress instead."
            pattern:
              spec:
                containers:
                  - ports:
                      - =(hostPort): null
  YAML

  depends_on = [time_sleep.wait_for_kyverno]
}

# =============================================================================
# SECURITY POLICY: DROP ALL CAPABILITIES
# =============================================================================
# Effect: Requires containers to drop all Linux capabilities
# Why: Linux capabilities are fine-grained root privileges:
#      - NET_ADMIN: Modify network settings
#      - SYS_ADMIN: Mount filesystems, load modules (very dangerous)
#      - DAC_OVERRIDE: Bypass file permission checks
#      Most applications don't need any capabilities
# Impact: Blocks pods that don't explicitly drop ALL capabilities
resource "kubectl_manifest" "policy_drop_all_capabilities" {
  count = var.enable_kyverno_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: drop-all-capabilities
      annotations:
        policies.kyverno.io/title: Drop All Capabilities
        policies.kyverno.io/category: Pod Security
        policies.kyverno.io/severity: medium
        policies.kyverno.io/description: >-
          Containers should drop all Linux capabilities and only add back
          specific ones if absolutely required.
    spec:
      validationFailureAction: Audit
      background: true
      rules:
        - name: drop-all-caps
          match:
            any:
              - resources:
                  kinds:
                    - Pod
                  namespaces:
                    - "default"
                    - "apps-*"
          validate:
            message: "Containers must drop all capabilities. Set securityContext.capabilities.drop to ['ALL']."
            pattern:
              spec:
                containers:
                  - securityContext:
                      capabilities:
                        drop:
                          - ALL
  YAML

  depends_on = [time_sleep.wait_for_kyverno]
}

# =============================================================================
# SECURITY POLICY: REQUIRE READ-ONLY ROOT FILESYSTEM
# =============================================================================
# Effect: Requires containers to use a read-only root filesystem
# Why: Prevents attackers from writing malicious files:
#      - Can't download attack tools
#      - Can't modify application binaries
#      - Can't create backdoor scripts
#      Applications should write to mounted volumes (emptyDir, PVC)
# Impact: Blocks pods without readOnlyRootFilesystem: true
resource "kubectl_manifest" "policy_require_readonly_rootfs" {
  count = var.enable_kyverno_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: require-readonly-root-filesystem
      annotations:
        policies.kyverno.io/title: Require Read-Only Root Filesystem
        policies.kyverno.io/category: Pod Security
        policies.kyverno.io/severity: medium
        policies.kyverno.io/description: >-
          Containers should use a read-only root filesystem to prevent
          attackers from writing malicious files. Use mounted volumes for
          writable directories like /tmp.
    spec:
      validationFailureAction: Audit
      background: true
      rules:
        - name: readonly-rootfs
          match:
            any:
              - resources:
                  kinds:
                    - Pod
                  namespaces:
                    - "default"
                    - "apps-*"
          validate:
            message: "Containers must use a read-only root filesystem. Set securityContext.readOnlyRootFilesystem to true."
            pattern:
              spec:
                containers:
                  - securityContext:
                      readOnlyRootFilesystem: true
  YAML

  depends_on = [time_sleep.wait_for_kyverno]
}

# =============================================================================
# SECURITY POLICY: DISALLOW LATEST TAG
# =============================================================================
# Effect: Prevents using the :latest tag or no tag on container images
# Why: The :latest tag causes problems:
#      - Not reproducible - can change without notice
#      - Can't audit what's actually running
#      - Can't reliably rollback
#      - Cache invalidation issues
# Impact: Blocks pods using image:latest or image (implicit latest)
resource "kubectl_manifest" "policy_disallow_latest_tag" {
  count = var.enable_kyverno_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: disallow-latest-tag
      annotations:
        policies.kyverno.io/title: Disallow Latest Tag
        policies.kyverno.io/category: Best Practices
        policies.kyverno.io/severity: medium
        policies.kyverno.io/description: >-
          Images must use explicit version tags, not :latest. This ensures
          reproducibility and auditability of deployments.
    spec:
      validationFailureAction: Enforce
      background: true
      rules:
        - name: validate-image-tag
          match:
            any:
              - resources:
                  kinds:
                    - Pod
                  namespaces:
                    - "default"
                    - "apps-*"
          validate:
            message: "Images must have an explicit tag. The :latest tag is not allowed."
            pattern:
              spec:
                containers:
                  - image: "*:*"
        - name: validate-image-not-latest
          match:
            any:
              - resources:
                  kinds:
                    - Pod
                  namespaces:
                    - "default"
                    - "apps-*"
          validate:
            message: "The :latest tag is not allowed. Use a specific version tag."
            pattern:
              spec:
                containers:
                  - image: "!*:latest"
  YAML

  depends_on = [time_sleep.wait_for_kyverno]
}

# =============================================================================
# SECURITY POLICY: RESTRICT IMAGE REGISTRIES
# =============================================================================
# Effect: Only allows images from approved registries
# Why: Prevents deploying untrusted/unscanned images:
#      - Supply chain attacks
#      - Images with known vulnerabilities
#      - Malicious images from public registries
# Allowed registries (configured via variable):
#      - Your Azure Container Registry
#      - registry.k8s.io (Kubernetes official images)
#      - docker.io (for common base images)
#      - ghcr.io (GitHub Container Registry)
#      - quay.io (Red Hat registry)
# Impact: Blocks images from non-allowed registries
resource "kubectl_manifest" "policy_restrict_image_registries" {
  count = var.enable_kyverno_policies && var.enable_registry_restriction ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: restrict-image-registries
      annotations:
        policies.kyverno.io/title: Restrict Image Registries
        policies.kyverno.io/category: Supply Chain Security
        policies.kyverno.io/severity: high
        policies.kyverno.io/description: >-
          Only allows images from approved container registries to prevent
          supply chain attacks and ensure images are scanned for vulnerabilities.
    spec:
      validationFailureAction: Audit
      background: true
      rules:
        - name: validate-registries
          match:
            any:
              - resources:
                  kinds:
                    - Pod
                  namespaces:
                    - "default"
                    - "apps-*"
          validate:
            message: "Images must be from approved registries: ${join(", ", var.allowed_registries)}"
            pattern:
              spec:
                containers:
                  - image: "${join("* | ", var.allowed_registries)}*"
  YAML

  depends_on = [time_sleep.wait_for_kyverno]
}

# =============================================================================
# RESOURCE POLICY: REQUIRE RESOURCE LIMITS
# =============================================================================
# Effect: Requires CPU and memory limits on all containers
# Why: Without limits, a single pod can:
#      - Consume all node CPU, starving other pods
#      - Use all available memory, causing OOM kills
#      - Trigger node instability
# Applies to: default and apps-* namespaces only
# Impact: Blocks pods without resource limits specified
resource "kubectl_manifest" "policy_require_resource_limits" {
  count = var.enable_kyverno_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: require-resource-limits
      annotations:
        policies.kyverno.io/title: Require Resource Limits
        policies.kyverno.io/category: Resource Management
        policies.kyverno.io/severity: medium
        policies.kyverno.io/description: >-
          Containers must specify CPU and memory limits to prevent resource
          exhaustion and ensure fair resource allocation.
    spec:
      validationFailureAction: Audit
      background: true
      rules:
        - name: require-limits
          match:
            any:
              - resources:
                  kinds:
                    - Pod
                  namespaces:
                    - "default"
                    - "apps-*"
          validate:
            message: "CPU and memory limits are required for all containers."
            pattern:
              spec:
                containers:
                  - resources:
                      limits:
                        memory: "?*"
                        cpu: "?*"
  YAML

  depends_on = [time_sleep.wait_for_kyverno]
}

# =============================================================================
# RESOURCE POLICY: REQUIRE RESOURCE REQUESTS
# =============================================================================
# Effect: Requires CPU and memory requests on all containers
# Why: Without requests, Kubernetes scheduler:
#      - Can't properly place pods
#      - May overcommit nodes
#      - Causes resource contention and evictions
# Applies to: default and apps-* namespaces only
# Impact: Blocks pods without resource requests specified
resource "kubectl_manifest" "policy_require_resource_requests" {
  count = var.enable_kyverno_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: require-resource-requests
      annotations:
        policies.kyverno.io/title: Require Resource Requests
        policies.kyverno.io/category: Resource Management
        policies.kyverno.io/severity: medium
        policies.kyverno.io/description: >-
          Containers must specify CPU and memory requests to enable proper
          scheduling and prevent node overcommitment.
    spec:
      validationFailureAction: Audit
      background: true
      rules:
        - name: require-requests
          match:
            any:
              - resources:
                  kinds:
                    - Pod
                  namespaces:
                    - "default"
                    - "apps-*"
          validate:
            message: "CPU and memory requests are required for all containers."
            pattern:
              spec:
                containers:
                  - resources:
                      requests:
                        memory: "?*"
                        cpu: "?*"
  YAML

  depends_on = [time_sleep.wait_for_kyverno]
}

# =============================================================================
# AUDIT POLICY: RECOMMEND SECURITY CONTEXT
# =============================================================================
# Effect: Logs warnings for pods missing recommended security context settings
# What it checks:
#      - runAsNonRoot: true
#      - allowPrivilegeEscalation: false
#      - readOnlyRootFilesystem: true
#      - capabilities.drop: ["ALL"]
# Why: Visibility into which pods lack hardened security settings
# Note: Does NOT mutate or block - audit only
resource "kubectl_manifest" "policy_audit_securitycontext" {
  count = var.enable_kyverno_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: audit-default-securitycontext
      annotations:
        policies.kyverno.io/title: Audit Security Context Settings
        policies.kyverno.io/category: Pod Security
        policies.kyverno.io/severity: low
        policies.kyverno.io/description: >-
          Audits pods for recommended security context settings including
          runAsNonRoot, allowPrivilegeEscalation, readOnlyRootFilesystem,
          and dropping all capabilities. Logs violations only.
    spec:
      validationFailureAction: Audit
      background: true
      rules:
        - name: check-security-context
          match:
            any:
              - resources:
                  kinds:
                    - Pod
                  namespaces:
                    - "default"
                    - "apps-*"
          validate:
            message: >-
              Container is missing recommended security context settings.
              Recommended: runAsNonRoot=true, allowPrivilegeEscalation=false,
              readOnlyRootFilesystem=true, drop ALL capabilities.
            pattern:
              spec:
                containers:
                  - securityContext:
                      runAsNonRoot: true
                      allowPrivilegeEscalation: false
                      readOnlyRootFilesystem: true
                      capabilities:
                        drop:
                          - ALL
  YAML

  depends_on = [time_sleep.wait_for_kyverno]
}

# =============================================================================
# AUDIT POLICY: RECOMMEND RESOURCE LIMITS
# =============================================================================
# Effect: Logs warnings for pods missing resource requests/limits
# What it checks:
#      - CPU and memory requests
#      - CPU and memory limits
# Why: Visibility into which pods lack resource boundaries
# Note: Does NOT mutate or block - audit only
resource "kubectl_manifest" "policy_audit_resources" {
  count = var.enable_kyverno_policies ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: audit-default-resources
      annotations:
        policies.kyverno.io/title: Audit Resource Requests and Limits
        policies.kyverno.io/category: Resource Management
        policies.kyverno.io/severity: low
        policies.kyverno.io/description: >-
          Audits pods for resource requests and limits. Pods without proper
          resource allocation can cause node instability and scheduling issues.
          Logs violations only.
    spec:
      validationFailureAction: Audit
      background: true
      rules:
        - name: check-resource-requests-and-limits
          match:
            any:
              - resources:
                  kinds:
                    - Pod
                  namespaces:
                    - "default"
                    - "apps-*"
          validate:
            message: >-
              Container is missing resource requests and/or limits.
              Recommended: set CPU and memory for both requests and limits.
            pattern:
              spec:
                containers:
                  - resources:
                      requests:
                        cpu: "?*"
                        memory: "?*"
                      limits:
                        cpu: "?*"
                        memory: "?*"
  YAML

  depends_on = [time_sleep.wait_for_kyverno]
}