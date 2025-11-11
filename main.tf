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

provider "aws" {}

locals {
  project      = "eks-hello"
  cluster_name = "eks-hello"
  common_tags  = { Project = local.project }
}

variable "control_plane_azs" {
  description = "AZs to use for control plane subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

data "aws_caller_identity" "current" {}

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

data "aws_subnet" "public" {
  for_each = toset(data.aws_subnets.default_public.ids)
  id       = each.value
}

locals {
  two_public_subnets = slice(
    [for s in data.aws_subnet.public : s.id if contains(var.control_plane_azs, s.availability_zone)],
    0,
    2
  )
}

resource "aws_ec2_tag" "elb_role_tag" {
  for_each    = toset(local.two_public_subnets)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

resource "aws_ec2_tag" "cluster_share_tag" {
  for_each    = toset(local.two_public_subnets)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.cluster_name}"
  value       = "shared"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.2"

  cluster_name    = local.cluster_name
  cluster_version = "1.29"
  subnet_ids      = local.two_public_subnets
  vpc_id          = data.aws_vpc.default.id

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = false
  cluster_enabled_log_types       = ["api", "audit", "authenticator"]

  create_kms_key  = true
  kms_key_aliases = ["alias/eks/${local.cluster_name}"]

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

  eks_managed_node_groups = {
    default = {
      desired_size   = 2
      min_size       = 2
      max_size       = 3
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      subnet_ids     = local.two_public_subnets
      tags           = local.common_tags
    }
  }

  tags = merge(local.common_tags, { "terraform-aws-modules" = "eks" })
}

resource "time_sleep" "post_cluster_pause" {
  create_duration = "30s"
  triggers = {
    endpoint = module.eks.cluster_endpoint
    name     = module.eks.cluster_name
  }
  depends_on = [module.eks]
}

data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "Configure kubectl command"
  value       = "aws eks update-kubeconfig --region us-east-1 --name ${module.eks.cluster_name}"
}
