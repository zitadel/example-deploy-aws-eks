module "lb_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.60.0"

  role_name_prefix                       = "${var.cluster_name}-alb-"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    this = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = var.tags
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = var.chart_path
  namespace  = "kube-system"
  version    = "1.14.1"
  wait       = true
  timeout    = 600

  values = [
    yamlencode({
      clusterName = var.cluster_name
      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.lb_irsa.iam_role_arn
        }
      }
    })
  ]

  depends_on = [module.lb_irsa]
}

resource "kubectl_manifest" "alb_bootstrap" {
  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "alb-bootstrap"
      namespace = "kube-system"
      annotations = {
        "alb.ingress.kubernetes.io/group.name"      = var.alb_group_name
        "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
        "alb.ingress.kubernetes.io/target-type"     = "ip"
        "alb.ingress.kubernetes.io/subnets"         = join(",", var.subnet_ids)
        "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\":80},{\"HTTPS\":443}]"
        "alb.ingress.kubernetes.io/certificate-arn" = aws_acm_certificate.wildcard.arn
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
    aws_acm_certificate_validation.wildcard
  ]
}

data "kubernetes_ingress_v1" "alb_bootstrap" {
  metadata {
    name      = "alb-bootstrap"
    namespace = "kube-system"
  }

  depends_on = [kubectl_manifest.alb_bootstrap]
}

resource "time_sleep" "wait_for_alb" {
  depends_on      = [kubectl_manifest.alb_bootstrap]
  create_duration = "90s"
}