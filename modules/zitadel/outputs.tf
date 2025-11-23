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

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.this.endpoint
}

output "rds_address" {
  description = "RDS address"
  value       = aws_db_instance.this.address
}

output "rds_port" {
  description = "RDS port"
  value       = aws_db_instance.this.port
}

output "secrets_manager_secret_arn" {
  description = "Secrets Manager secret ARN"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

output "kubernetes_secret_name" {
  description = "Kubernetes secret name containing DB credentials"
  value       = kubernetes_secret.db_credentials.metadata[0].name
}