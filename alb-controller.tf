module "lb_irsa" {
  count   = var.deploy_post ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.60.0"

  role_name_prefix                       = "${module.eks.cluster_name}-alb-"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    this = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.common_tags
}

resource "helm_release" "aws_load_balancer_controller" {
  count      = var.deploy_post ? 1 : 0
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "./aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.14.1"

  wait    = true
  timeout = 600

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.lb_irsa[0].iam_role_arn
  }

  depends_on = [module.lb_irsa]
}