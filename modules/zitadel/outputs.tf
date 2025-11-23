output "ingress_hostname" {
  description = "ALB DNS hostname for Zitadel"
  value       = try(data.kubernetes_ingress_v1.zitadel.status[0].load_balancer[0].ingress[0].hostname, "<pending>")
}

output "service_name" {
  description = "Kubernetes service name"
  value       = "zitadel"
}

output "namespace" {
  description = "Kubernetes namespace"
  value       = var.namespace
}