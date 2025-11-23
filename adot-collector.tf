data "aws_region" "current" {}

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
      awsRegion   = data.aws_region.current.name

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