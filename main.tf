terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Region comes from your AWS CLI config/profile (you already have us-east-1)
provider "aws" {
  # region = "us-east-1"
}

locals {
  project      = "eks-hello"
  cluster_name = "eks-hello"
  common_tags  = { Project = local.project }
}

# --- Choose control plane AZs (EKS requires at least two supported AZs) ---
variable "control_plane_azs" {
  description = "AZs to use for control plane subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# --- Discover default VPC and its default-per-AZ public subnets ---
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Index each subnet so we can read attributes like AvailabilityZone
data "aws_subnet" "public" {
  for_each = toset(data.aws_subnets.default_public.ids)
  id       = each.value
}

# Keep only subnets whose AZ is in var.control_plane_azs, then take first two
locals {
  two_public_subnets = slice(
    [for s in data.aws_subnet.public : s.id if contains(var.control_plane_azs, s.availability_zone)],
    0,
    2
  )
}

# Tag those subnets so classic ELBs can be placed there by Kubernetes (optional but common)
resource "aws_ec2_tag" "elb_role_tag" {
  for_each    = toset(local.two_public_subnets)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

# --- EKS Cluster using terraform-aws-modules/eks ---
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.2"

  cluster_name    = local.cluster_name
  cluster_version = "1.29"

  # Only pass the two supported public subnets
  subnet_ids = local.two_public_subnets

  vpc_id = data.aws_vpc.default.id

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = false

  # Enable control plane logs (useful, and you already used them)
  cluster_enabled_log_types = ["api", "audit", "authenticator"]

  # Create a KMS key for secrets encryption (mirrors your previous plan)
  create_kms_key = true
  kms_key_aliases = ["alias/eks/${local.cluster_name}"]

  # Grant your SSO admin role admin access to the cluster via EKS Access Entries
  enable_cluster_creator_admin_permissions = false
  access_entries = {
    cluster_creator = {
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_b588c55e5cae07b9"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # Minimal managed node group
  eks_managed_node_groups = {
    default = {
      desired_size = 2
      min_size     = 2
      max_size     = 3

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      subnet_ids = local.two_public_subnets

      tags = local.common_tags
    }
  }

  tags = merge(local.common_tags, { "terraform-aws-modules" = "eks" })
}

data "aws_caller_identity" "current" {}

# Give the control plane a few seconds to stabilize before depending resources (handy for follow-on Helm/K8s)
resource "time_sleep" "post_cluster_pause" {
  create_duration = "30s"
  triggers = {
    endpoint = module.eks.cluster_endpoint
    name     = module.eks.cluster_name
  }
}

# --- (Optional) Wire up Kubernetes/Helm providers if you plan to install addons here ---
# provider "kubernetes" {
#   host                   = module.eks.cluster_endpoint
#   cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
#   token                  = data.aws_eks_cluster_auth.this.token
# }
#
# data "aws_eks_cluster_auth" "this" {
#   name = module.eks.cluster_name
# }
#
# provider "helm" {
#   kubernetes {
#     host                   = module.eks.cluster_endpoint
#     cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
#     token                  = data.aws_eks_cluster_auth.this.token
#   }
# }

# --- Outputs ---
output "cluster_name" {
  value = module.eks.cluster_name
}

output "next_steps" {
  description = "What to do next"
  value       = "Now run: terraform apply -auto-approve -var='deploy_post=true' (to install ALB controller + hello, if you add those resources later)."
}
