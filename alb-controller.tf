// file: alb-controller.tf
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

  values = [
    yamlencode({
      clusterName = module.eks.cluster_name
      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.lb_irsa[0].iam_role_arn
        }
      }
    })
  ]

  depends_on = [module.lb_irsa]
}

resource "kubectl_manifest" "alb_bootstrap" {
  count = var.deploy_post ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "alb-bootstrap"
      namespace = "kube-system"
      annotations = {
        "alb.ingress.kubernetes.io/group.name"           = "podinfo"
        "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
        "alb.ingress.kubernetes.io/target-type"          = "ip"
        "alb.ingress.kubernetes.io/subnets"              = join(",", local.two_public_subnets)
        "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTP\":80},{\"HTTPS\":443}]"
        "alb.ingress.kubernetes.io/certificate-arn"      = aws_acm_certificate.wildcard.arn
        "alb.ingress.kubernetes.io/actions.health-check" = jsonencode({
          type = "fixed-response"
          fixedResponseConfig = {
            statusCode  = "204"
            contentType = "text/plain"
          }
        })
      }
    }
    spec = {
      ingressClassName = "alb"
      rules = [
        {
          http = {
            paths = [
              {
                path     = "/health"
                pathType = "Exact"
                backend = {
                  service = {
                    name = "health-check"
                    port = {
                      name = "use-annotation"
                    }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  })

  depends_on = [
    helm_release.aws_load_balancer_controller,
    aws_acm_certificate_validation.wildcard,
    time_sleep.post_cluster_pause
  ]
}

data "kubernetes_ingress_v1" "alb_bootstrap" {
  count = var.deploy_post ? 1 : 0

  metadata {
    name      = "alb-bootstrap"
    namespace = "kube-system"
  }

  depends_on = [kubectl_manifest.alb_bootstrap]
}

output "alb_bootstrap_hostname" {
  description = "Bootstrap ALB DNS name"
  value       = try(data.kubernetes_ingress_v1.alb_bootstrap[0].status[0].load_balancer[0].ingress[0].hostname, "<pending>")
}