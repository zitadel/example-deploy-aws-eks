variable "control_plane_azs" {
  description = "AZs to use for control plane subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "deploy_post" {
  description = "Install AWS Load Balancer Controller and Podinfo app with ALB Ingress"
  type        = bool
  default     = true
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for the subdomain"
  type        = string
}

variable "app_domain" {
  description = "Domain name for the application"
  type        = string
}

variable "wildcard_domain" {
  description = "Wildcard domain for ACM certificate (e.g., *.aws.mrida.ng)"
  type        = string
}
variable "zitadel_domain" {
  description = "Domain name for Zitadel"
  type        = string
  default     = "zitadel.aws.mrida.ng"
}