locals {
  adot_namespace        = "amazon-cloudwatch"
  adot_service_account  = "adot-collector"
  adot_release_name     = "adot-collector"
  adot_chart_path       = "./adot-exporter-for-eks-on-ec2"
  adot_image_tag        = "v0.45.1"
  adot_service_name     = "adot-collector-daemonset-service"
}

data "aws_region" "current" {}

module "adot_irsa" {
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
      namespace_service_accounts = ["${local.adot_namespace}:${local.adot_service_account}"]
    }
  }

  tags = local.common_tags
}

resource "helm_release" "adot_collector" {
  name  = local.adot_release_name
  chart = local.adot_chart_path
  namespace        = local.adot_namespace
  create_namespace = true
  wait             = true
  timeout          = 300

  values = [
    yamlencode({
      clusterName = module.eks.cluster_name
      awsRegion   = data.aws_region.current.name

      adotCollector = {
        image = {
          tag = local.adot_image_tag
        }
        daemonSet = {
          createNamespace = false
          namespace       = local.adot_namespace
          serviceAccount = {
            create = true
            name   = local.adot_service_account
            annotations = {
              "eks.amazonaws.com/role-arn" = module.adot_irsa.iam_role_arn
            }
          }
          service = {
            name = local.adot_service_name
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

output "otlp_grpc_endpoint" {
  description = "ADOT Collector OTLP gRPC endpoint"
  # noinspection HttpUrlsUsage
  value       = "http://${local.adot_service_name}.${local.adot_namespace}.svc.cluster.local:4317"
}

output "otlp_http_endpoint" {
  description = "ADOT Collector OTLP HTTP endpoint"
  # noinspection HttpUrlsUsage
  value       = "http://${local.adot_service_name}.${local.adot_namespace}.svc.cluster.local:4318"
}