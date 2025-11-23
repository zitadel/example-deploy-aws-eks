module "zitadel" {
  source = "./modules/zitadel"
  count  = var.deploy_post ? 1 : 0

  namespace       = "zitadel"
  cluster_name    = module.eks.cluster_name
  domain          = var.zitadel_domain
  certificate_arn = aws_acm_certificate.wildcard.arn
  subnet_ids      = local.two_public_subnets
  alb_group_name  = "podinfo"
  otlp_endpoint   = "http://adot-collector-daemonset-service.amazon-cloudwatch.svc.cluster.local:4317"

  common_tags = local.common_tags

  depends_on = [
    helm_release.aws_load_balancer_controller,
    helm_release.adot_collector,
    aws_acm_certificate_validation.wildcard
  ]
}

output "zitadel_url" {
  value = var.deploy_post ? "https://${var.zitadel_domain}" : "Not deployed"
}