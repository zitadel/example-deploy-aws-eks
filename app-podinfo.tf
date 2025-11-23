// file: app-podinfo.tf
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
          value = "http://adot-collector-daemonset-service.amazon-cloudwatch.svc.cluster.local:4317"
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

resource "kubectl_manifest" "podinfo_grpc_ingress" {
  count = var.deploy_post ? 1 : 0

  yaml_body = yamlencode({
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
  })

  depends_on = [helm_release.podinfo, time_sleep.post_cluster_pause]
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