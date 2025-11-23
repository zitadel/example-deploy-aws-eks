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
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_caller_identity" "current" {}

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
