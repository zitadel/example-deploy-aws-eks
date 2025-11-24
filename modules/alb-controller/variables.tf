variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  type        = string
}

variable "chart_path" {
  description = "Path to the ALB controller Helm chart"
  type        = string
}

variable "alb_group_name" {
  description = "ALB ingress group name"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ALB"
  type        = list(string)
}

variable "route53_zone_id" {
  description = "Route53 zone ID for DNS records"
  type        = string
}

variable "wildcard_domain" {
  description = "Wildcard domain for certificate"
  type        = string
}

variable "tags" {
  description = "Tags to apply to AWS resources"
  type        = map(string)
  default     = {}
}