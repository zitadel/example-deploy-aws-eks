data "aws_region" "current" {}

module "adot_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.60.0"

  role_name_prefix = "${var.cluster_name}-adot-"

  role_policy_arns = {
    CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    XRayDaemonWriteAccess       = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
  }

  oidc_providers = {
    this = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["${var.namespace}:${var.service_account}"]
    }
  }

  tags = var.tags
}

resource "helm_release" "adot_collector" {
  name             = var.release_name
  chart            = var.chart_path
  namespace        = var.namespace
  create_namespace = true
  wait             = true
  timeout          = 300

  values = [
    yamlencode({
      clusterName = var.cluster_name
      awsRegion   = data.aws_region.current.name

      adotCollector = {
        image = {
          tag = var.image_tag
        }
        daemonSet = {
          createNamespace = false
          namespace       = var.namespace
          serviceAccount = {
            create = true
            name   = var.service_account
            annotations = {
              "eks.amazonaws.com/role-arn" = module.adot_irsa.iam_role_arn
            }
          }
          service = {
            name = var.service_name
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