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

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.34"
}

variable "node_instance_types" {
  description = "Instance types for EKS node groups"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of nodes in the EKS node group"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of nodes in the EKS node group"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of nodes in the EKS node group"
  type        = number
  default     = 3
}

variable "zitadel_masterkey" {
  description = "Zitadel master key (must be exactly 32 characters)"
  type        = string
  sensitive   = true
}

variable "zitadel_admin_username" {
  description = "Initial Zitadel admin username"
  type        = string
  default     = "zitadel-admin"
}

variable "zitadel_admin_password" {
  description = "Initial Zitadel admin password"
  type        = string
  sensitive   = true
  default     = "Password1!"
}

variable "zitadel_admin_email" {
  description = "Initial Zitadel admin email"
  type        = string
  default     = "admin@localhost"
}