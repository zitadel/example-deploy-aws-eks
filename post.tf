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

module "adot_irsa" {
  count   = var.deploy_post ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.60.0"

  role_name_prefix = "${module.eks.cluster_name}-adot-"

  role_policy_arns = {
    CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    XRayDaemonWriteAccess       = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
  }

  oidc_providers = {
    this = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["amazon-cloudwatch:adot-collector"]
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

resource "helm_release" "adot_collector" {
  count = var.deploy_post ? 1 : 0

  name  = "adot-collector"
  chart = "./adot-exporter-for-eks-on-ec2"

  namespace        = "amazon-cloudwatch"
  create_namespace = true
  wait             = true
  timeout          = 300

  values = [
    yamlencode({
      clusterName = module.eks.cluster_name
      region      = data.aws_region.current.name

      adotCollector = {
        image = {
          tag = "v0.45.1"
        }
        daemonSet = {
          createNamespace = false
          namespace       = "amazon-cloudwatch"
          serviceAccount = {
            create = true
            name   = "adot-collector"
            annotations = {
              "eks.amazonaws.com/role-arn" = module.adot_irsa[0].iam_role_arn
            }
          }
          service = {
            metrics = {
              receivers  = ["awscontainerinsightreceiver", "prometheus"]
              processors = ["batch/metrics"]
              exporters  = ["awsemf"]
            }
            extensions = ["health_check", "sigv4auth"]
          }
        }
      }
    })
  ]

  depends_on = [module.adot_irsa]
}

resource "helm_release" "podinfo" {
  count = var.deploy_post ? 1 : 0

  name             = "podinfo"
  chart            = "./podinfo"
  namespace        = "hello"
  create_namespace = true
  wait             = true
  timeout          = 300

  values = [
    yamlencode({
      service = {
        type         = "ClusterIP"
        httpPort     = 9898
        externalPort = 9898
        grpcPort     = 9999
      }
      extraEnvs = [
        {
          name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
          value = "adot-collector-daemonset-service.amazon-cloudwatch.svc.cluster.local:4317"
        }
      ]
      extraArgs = [
        "--otel-service-name=podinfo"
      ]
      ingress = {
        enabled   = true
        className = "alb"
        annotations = {
          "alb.ingress.kubernetes.io/group.name"       = "podinfo"
          "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
          "alb.ingress.kubernetes.io/target-type"      = "ip"
          "alb.ingress.kubernetes.io/healthcheck-path" = "/healthz"
          "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\":80},{\"HTTPS\":443}]"
          "alb.ingress.kubernetes.io/ssl-redirect"     = "443"
          "alb.ingress.kubernetes.io/certificate-arn"  = aws_acm_certificate.wildcard.arn
          "alb.ingress.kubernetes.io/subnets"          = join(",", local.two_public_subnets)
          "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
        }
        hosts = [
          {
            host = var.app_domain
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
              }
            ]
          }
        ]
      }
    })
  ]

  depends_on = [helm_release.aws_load_balancer_controller, aws_acm_certificate_validation.wildcard]
}

resource "kubernetes_manifest" "podinfo_grpc_ingress" {
  count = var.deploy_post ? 1 : 0

  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "podinfo-grpc"
      namespace = "hello"
      annotations = {
        "alb.ingress.kubernetes.io/group.name"               = "podinfo"
        "alb.ingress.kubernetes.io/scheme"                   = "internet-facing"
        "alb.ingress.kubernetes.io/target-type"              = "ip"
        "alb.ingress.kubernetes.io/backend-protocol-version" = "HTTP2"
        "alb.ingress.kubernetes.io/listen-ports"             = "[{\"HTTPS\":8443}]"
        "alb.ingress.kubernetes.io/certificate-arn"          = aws_acm_certificate.wildcard.arn
        "alb.ingress.kubernetes.io/subnets"                  = join(",", local.two_public_subnets)
      }
    }
    spec = {
      ingressClassName = "alb"
      rules = [
        {
          http = {
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "podinfo"
                    port = {
                      number = 9999
                    }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  }

  depends_on = [helm_release.podinfo]
}

data "kubernetes_ingress_v1" "podinfo_ingress" {
  count = var.deploy_post ? 1 : 0

  metadata {
    name      = "podinfo"
    namespace = "hello"
  }

  depends_on = [helm_release.podinfo]
}

output "alb_hostname" {
  description = "ALB DNS name for the podinfo Ingress"
  value       = try(data.kubernetes_ingress_v1.podinfo_ingress[0].status[0].load_balancer[0].ingress[0].hostname, "<pending>")
}

output "curl_example" {
  description = "Test command for the ALB"
  value       = format("curl -sS http://%s", try(data.kubernetes_ingress_v1.podinfo_ingress[0].status[0].load_balancer[0].ingress[0].hostname, "ALB_HOSTNAME"))
}