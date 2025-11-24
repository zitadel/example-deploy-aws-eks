output "otlp_grpc_endpoint" {
  description = "ADOT Collector OTLP gRPC endpoint"
  # noinspection HttpUrlsUsage
  value       = "http://${var.service_name}.${var.namespace}.svc.cluster.local:4317"
}

output "otlp_http_endpoint" {
  description = "ADOT Collector OTLP HTTP endpoint"
  # noinspection HttpUrlsUsage
  value       = "http://${var.service_name}.${var.namespace}.svc.cluster.local:4318"
}