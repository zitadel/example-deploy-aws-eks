resource "aws_route53_record" "wildcard" {
  zone_id = data.aws_route53_zone.subdomain.zone_id
  name    = var.wildcard_domain
  type    = "A"

  alias {
    name                   = data.kubernetes_ingress_v1.alb_bootstrap.status[0].load_balancer[0].ingress[0].hostname
    zone_id                = data.aws_elb_hosted_zone_id.main.id
    evaluate_target_health = true
  }

  depends_on = [data.kubernetes_ingress_v1.alb_bootstrap, time_sleep.wait_for_alb]
}