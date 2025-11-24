resource "helm_release" "zitadel" {
  name             = "zitadel"
  chart            = "${path.root}/zitadel"
  namespace        = var.namespace
  create_namespace = true
  atomic           = true
  timeout          = 6000
  values = [
    yamlencode({
      image = {
        tag = var.image_tag
      }

      replicaCount = 2

      service = {
        type        = "ClusterIP"
        port        = 8080
        protocol    = "http"
        appProtocol = "http"
      }

      ingress = {
        enabled    = true
        className  = var.ingress_class
        controller = "aws"
        annotations = {
          "alb.ingress.kubernetes.io/group.name"       = var.alb_group_name
          "alb.ingress.kubernetes.io/scheme"           = var.alb_scheme
          "alb.ingress.kubernetes.io/target-type"      = var.alb_target_type
          "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\":80},{\"HTTPS\":443}]"
          "alb.ingress.kubernetes.io/ssl-redirect"     = "443"
          "alb.ingress.kubernetes.io/certificate-arn"  = var.certificate_arn
          "alb.ingress.kubernetes.io/subnets"          = join(",", var.subnet_ids)
          "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
          "alb.ingress.kubernetes.io/healthcheck-path" = "/debug/healthz"
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

      login = {
        enabled = true
        ingress = {
          enabled     = true
          className   = var.ingress_class
          controller  = "aws"
          annotations = {
            "alb.ingress.kubernetes.io/group.name"       = var.alb_group_name
            "alb.ingress.kubernetes.io/group.order"      = "-2"
            "alb.ingress.kubernetes.io/scheme"           = var.alb_scheme
            "alb.ingress.kubernetes.io/target-type"      = var.alb_target_type
            "alb.ingress.kubernetes.io/certificate-arn"  = var.certificate_arn
            "alb.ingress.kubernetes.io/subnets"          = join(",", var.subnet_ids)
            "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
          }
        }
      }

      initJob = {
        enabled               = true
        activeDeadlineSeconds = 600
        backoffLimit          = 5
      }

      setupJob = {
        enabled               = true
        activeDeadlineSeconds = 600
        backoffLimit          = 5
      }

      metrics = {
        enabled = true
        serviceMonitor = {
          enabled = false
        }
      }

      env = [
        {
          name  = "ZITADEL_TRACING_TYPE"
          value = "otel"
        },
        {
          name  = "ZITADEL_TRACING_ENDPOINT"
          value = var.otlp_endpoint
        },
        {
          name  = "ZITADEL_TRACING_SERVICENAME"
          value = "zitadel"
        },
        {
          name  = "OTEL_METRICS_EXEMPLAR_FILTER"
          value = "always_off"
        },
        {
          name  = "OTEL_LOG_LEVEL"
          value = "error"
        }
      ]

      zitadel = {
        masterkey = var.zitadel_masterkey

        configmapConfig = {
          ExternalPort   = 443
          ExternalSecure = true
          ExternalDomain = var.domain

          TLS = {
            Enabled = false
          }

          Database = {
            Postgres = {
              Host     = aws_db_instance.this.address
              Port     = aws_db_instance.this.port
              Database = aws_db_instance.this.db_name
              User = {
                Username = aws_db_instance.this.username
                Password = random_password.db_password.result
                SSL = {
                  Mode = "require"
                }
              }
              Admin = {
                Username = var.db_master_username
                Password = random_password.db_password.result
                SSL = {
                  Mode = "require"
                }
              }
            }
          }

          FirstInstance = {
            Org = {
              Human = {
                UserName               = var.zitadel_admin_username
                Password               = var.zitadel_admin_password
                FirstName              = "ZITADEL"
                LastName               = "Admin"
                Email                  = var.zitadel_admin_email
                PasswordChangeRequired = false
              }
            }
          }
        }
      }
    })
  ]

  depends_on = [
    aws_db_instance.this,
    aws_secretsmanager_secret_version.db_credentials
  ]
}

data "kubernetes_ingress_v1" "zitadel" {
  metadata {
    name      = "zitadel"
    namespace = var.namespace
  }

  depends_on = [helm_release.zitadel]
}