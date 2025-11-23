resource "helm_release" "zitadel" {
  name             = "zitadel"
  chart            = "./podinfo"
  namespace        = var.namespace
  create_namespace = true
  wait             = true
  timeout          = 300

  values = [
    yamlencode({
      service = {
        type         = "ClusterIP"
        httpPort     = var.service_http_port
        externalPort = var.service_http_port
        grpcPort     = var.service_grpc_port
      }
      extraEnvs = [
        {
          name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
          value = var.otlp_endpoint
        }
      ]
      extraArgs = [
        "--otel-service-name=${var.otlp_service_name}"
      ]
      ingress = {
        enabled   = true
        className = var.ingress_class
        annotations = {
          "alb.ingress.kubernetes.io/group.name"       = var.alb_group_name
          "alb.ingress.kubernetes.io/scheme"           = var.alb_scheme
          "alb.ingress.kubernetes.io/target-type"      = var.alb_target_type
          "alb.ingress.kubernetes.io/healthcheck-path" = var.healthcheck_path
          "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\":80},{\"HTTPS\":443}]"
          "alb.ingress.kubernetes.io/ssl-redirect"     = "443"
          "alb.ingress.kubernetes.io/certificate-arn"  = var.certificate_arn
          "alb.ingress.kubernetes.io/subnets"          = join(",", var.subnet_ids)
          "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
        }
        hosts = [
          {
            host = var.domain
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
}

resource "kubectl_manifest" "zitadel_grpc_ingress" {
  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "zitadel-grpc"
      namespace = var.namespace
      annotations = {
        "alb.ingress.kubernetes.io/group.name"               = var.alb_group_name
        "alb.ingress.kubernetes.io/scheme"                   = var.alb_scheme
        "alb.ingress.kubernetes.io/target-type"              = var.alb_target_type
        "alb.ingress.kubernetes.io/backend-protocol-version" = "HTTP2"
        "alb.ingress.kubernetes.io/listen-ports"             = "[{\"HTTPS\":8443}]"
        "alb.ingress.kubernetes.io/certificate-arn"          = var.certificate_arn
        "alb.ingress.kubernetes.io/subnets"                  = join(",", var.subnet_ids)
      }
    }
    spec = {
      ingressClassName = var.ingress_class
      rules = [
        {
          http = {
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "zitadel"
                    port = {
                      number = var.service_grpc_port
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

  depends_on = [helm_release.zitadel]
}

data "kubernetes_ingress_v1" "zitadel" {
  metadata {
    name      = "zitadel"
    namespace = var.namespace
  }

  depends_on = [helm_release.zitadel]
}
