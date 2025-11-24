output "alb_hostname" {
  description = "Bootstrap ALB DNS hostname"
  value       = try(data.kubernetes_ingress_v1.alb_bootstrap.status[0].load_balancer[0].ingress[0].hostname, null)
}

output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = aws_acm_certificate.wildcard.arn
}

output "wildcard_domain_fqdn" {
  description = "Wildcard domain FQDN"
  value       = aws_route53_record.wildcard.fqdn
}