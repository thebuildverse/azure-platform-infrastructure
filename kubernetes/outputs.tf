output "ingress_nginx_namespace" {
  description = "Ingress NGINX namespace"
  value       = helm_release.ingress_nginx.namespace
}

output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = helm_release.argocd.namespace
}

output "external_secrets_namespace" {
  description = "External Secrets namespace"
  value       = helm_release.external_secrets.namespace
}

output "kyverno_namespace" {
  description = "Kyverno namespace (if enabled)"
  value       = var.enable_kyverno ? helm_release.kyverno[0].namespace : null
}
