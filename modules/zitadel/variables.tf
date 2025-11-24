variable "namespace" {
  description = "Kubernetes namespace for Zitadel deployment"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "domain" {
  description = "Domain name for Zitadel"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ALB placement"
  type        = list(string)
}

variable "alb_group_name" {
  description = "ALB Ingress group name"
  type        = string
}

variable "otlp_endpoint" {
  description = "OTLP collector endpoint"
  type        = string
}

variable "alb_scheme" {
  description = "ALB scheme"
  type        = string
  default     = "internet-facing"
}

variable "alb_target_type" {
  description = "ALB target type"
  type        = string
  default     = "ip"
}

variable "ingress_class" {
  description = "Ingress class name"
  type        = string
  default     = "alb"
}

variable "common_tags" {
  description = "Common tags for resources"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "VPC ID for RDS"
  type        = string
}

variable "eks_node_security_group_id" {
  description = "EKS node security group ID for RDS access"
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "zitadel"
}

variable "db_master_username" {
  description = "Master username"
  type        = string
  default     = "postgres"
}

variable "zitadel_masterkey" {
  description = "Zitadel master key (must be exactly 32 characters)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.zitadel_masterkey) == 32
    error_message = "Zitadel masterkey must be exactly 32 characters long."
  }
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

variable "chart_version" {
  description = "Zitadel Helm chart version"
  type        = string
  default     = "9.13.0"
}

variable "image_tag" {
  description = "Zitadel image tag"
  type        = string
  default     = "v4.2.0"
}