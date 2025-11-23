# Create Route53 hosted zone for aws.mrida.ng subdomain
resource "aws_route53_zone" "aws_subdomain" {
  name = "aws.mrida.ng"
  tags = local.common_tags
}

# Create A record for eksdemo.aws.mrida.ng pointing to ALB (only when deploy_post is true)
resource "aws_route53_record" "eksdemo" {
  count   = var.deploy_post ? 1 : 0
  zone_id = aws_route53_zone.aws_subdomain.zone_id
  name    = "eksdemo.aws.mrida.ng"
  type    = "A"

  alias {
    name                   = data.kubernetes_ingress_v1.podinfo_ingress[0].status[0].load_balancer[0].ingress[0].hostname
    zone_id                = data.aws_elb_hosted_zone_id.main.id
    evaluate_target_health = true
  }

  depends_on = [
    data.kubernetes_ingress_v1.podinfo_ingress
  ]
}

# Get the ALB hosted zone ID based on region
data "aws_elb_hosted_zone_id" "main" {}

# Output Route53 nameservers for manual Cloudflare configuration
output "route53_nameservers" {
  description = "Add these 4 nameservers as NS records in Cloudflare for 'aws' subdomain"
  value       = aws_route53_zone.aws_subdomain.name_servers
}

output "eksdemo_url" {
  description = "URL for your application"
  value       = var.deploy_post ? "https://eksdemo.aws.mrida.ng" : "Not deployed (set deploy_post=true)"
}
