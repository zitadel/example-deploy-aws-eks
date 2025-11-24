locals {
  adot_namespace       = "amazon-cloudwatch"
  adot_service_account = "adot-collector"
  adot_release_name    = "adot-collector"
  adot_chart_path      = "./adot-exporter-for-eks-on-ec2"
  adot_image_tag       = "v0.45.1"
  adot_service_name    = "adot-collector-daemonset-service"
}

module "collector_support" {
  source = "./modules/collector-support"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  namespace         = local.adot_namespace
  service_account   = local.adot_service_account
  release_name      = local.adot_release_name
  chart_path        = local.adot_chart_path
  image_tag         = local.adot_image_tag
  service_name      = local.adot_service_name
  tags              = local.common_tags
}

output "otlp_grpc_endpoint" {
  description = "ADOT Collector OTLP gRPC endpoint"
  value       = module.collector_support.otlp_grpc_endpoint
}

output "otlp_http_endpoint" {
  description = "ADOT Collector OTLP HTTP endpoint"
  value       = module.collector_support.otlp_http_endpoint
}