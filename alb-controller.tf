module "alb_controller" {
  count  = var.deploy_post ? 1 : 0
  source = "./modules/alb-controller"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  chart_path        = "./aws-load-balancer-controller"
  alb_group_name    = "podinfo"
  subnet_ids        = local.two_public_subnets
  route53_zone_id   = var.route53_zone_id
  wildcard_domain   = var.wildcard_domain
  tags              = local.common_tags

  depends_on = [time_sleep.post_cluster_pause]
}

output "alb_bootstrap_hostname" {
  description = "Bootstrap ALB DNS name"
  value       = var.deploy_post ? module.alb_controller[0].alb_hostname : "Not deployed"
}

output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = var.deploy_post ? module.alb_controller[0].certificate_arn : "Not deployed"
}

output "app_url" {
  value = var.deploy_post ? "https://${var.app_domain}" : "Not deployed"
}