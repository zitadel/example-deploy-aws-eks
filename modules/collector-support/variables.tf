variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for ADOT collector"
  type        = string
  default     = "amazon-cloudwatch"
}

variable "service_account" {
  description = "Kubernetes service account name for ADOT collector"
  type        = string
  default     = "adot-collector"
}

variable "release_name" {
  description = "Helm release name for ADOT collector"
  type        = string
  default     = "adot-collector"
}

variable "chart_path" {
  description = "Path to the ADOT Helm chart"
  type        = string
}

variable "image_tag" {
  description = "ADOT collector image tag"
  type        = string
  default     = "v0.45.1"
}

variable "service_name" {
  description = "Kubernetes service name for ADOT collector"
  type        = string
  default     = "adot-collector-daemonset-service"
}

variable "tags" {
  description = "Tags to apply to AWS resources"
  type        = map(string)
  default     = {}
}