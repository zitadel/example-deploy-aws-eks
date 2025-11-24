module "zitadel" {
  source = "./modules/zitadel"
  count  = var.deploy_post ? 1 : 0

  namespace                  = "zitadel"
  cluster_name               = module.eks.cluster_name
  domain                     = var.zitadel_domain
  certificate_arn            = module.alb_controller[0].certificate_arn
  subnet_ids                 = local.two_public_subnets
  alb_group_name             = "podinfo"
  otlp_endpoint              = module.collector_support.otlp_grpc_endpoint
  vpc_id                     = data.aws_vpc.default.id
  eks_node_security_group_id = module.eks.node_security_group_id
  common_tags                = local.common_tags

  depends_on = [
    module.alb_controller,
    module.collector_support
  ]
}

output "zitadel_url" {
  value = var.deploy_post ? "https://${var.zitadel_domain}" : "Not deployed"
}

output "zitadel_rds_endpoint" {
  description = "Zitadel RDS endpoint"
  value       = var.deploy_post ? module.zitadel[0].rds_endpoint : "Not deployed"
}

output "zitadel_db_secret_arn" {
  description = "Zitadel DB credentials secret ARN"
  value       = var.deploy_post ? module.zitadel[0].secrets_manager_secret_arn : "Not deployed"
}