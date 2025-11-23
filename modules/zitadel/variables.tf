variable "namespace" {
  description = "Kubernetes namespace for Zitadel deployment"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "domain" {
  description = "Domain name for Zitadel (e.g., zitadel.aws.mrida.ng)"
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

variable "otlp_service_name" {
  description = "Service name for OTLP traces"
  type        = string
  default     = "zitadel"
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

variable "service_http_port" {
  description = "HTTP service port"
  type        = number
  default     = 9898
}

variable "service_grpc_port" {
  description = "gRPC service port"
  type        = number
  default     = 9999
}

variable "healthcheck_path" {
  description = "Health check path"
  type        = string
  default     = "/healthz"
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
