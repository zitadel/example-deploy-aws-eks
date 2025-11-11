variable "deploy_post" {
  description = "Install AWS Load Balancer Controller and Hello World app with ALB Ingress"
  type        = bool
  default     = false
}

data "aws_region" "current" {}

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

resource "helm_release" "hello_world" {
  count = var.deploy_post ? 1 : 0

  name             = "hello-world"
  chart            = "./nginx"
  namespace        = "hello"
  create_namespace = true
  wait             = true
  timeout          = 300

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  set {
    name  = "ingress.enabled"
    value = "true"
  }

  set {
    name  = "ingress.hostname"
    value = ""
  }

  set {
    name  = "ingress.ingressClassName"
    value = "alb"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/healthcheck-path"
    value = "/"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports"
    value = "[{\"HTTP\":80}]"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/subnets"
    value = join("\\,", local.two_public_subnets)
  }

  depends_on = [helm_release.aws_load_balancer_controller]
}

data "kubernetes_ingress_v1" "hello_ingress" {
  count = var.deploy_post ? 1 : 0

  metadata {
    name      = "hello-world-nginx"
    namespace = "hello"
  }

  depends_on = [helm_release.hello_world]
}

output "alb_hostname" {
  description = "ALB DNS name for the hello Ingress"
  value       = try(data.kubernetes_ingress_v1.hello_ingress[0].status[0].load_balancer[0].ingress[0].hostname, "<pending>")
}

output "curl_example" {
  description = "Test command for the ALB"
  value       = format("curl -sS http://%s", try(data.kubernetes_ingress_v1.hello_ingress[0].status[0].load_balancer[0].ingress[0].hostname, "ALB_HOSTNAME"))
}
