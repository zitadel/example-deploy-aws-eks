resource "random_password" "db_password" {
  length  = 32
  special = true
}

resource "aws_security_group" "rds" {
  name_prefix = "${var.cluster_name}-${var.namespace}-rds-"
  vpc_id      = var.vpc_id
  description = "Security group for ${var.namespace} RDS instance"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id]
    description     = "PostgreSQL from EKS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-${var.namespace}-rds"
    }
  )
}

resource "aws_db_subnet_group" "this" {
  name_prefix = "${var.cluster_name}-${var.namespace}-"
  subnet_ids  = var.subnet_ids
  description = "Subnet group for ${var.namespace} RDS"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-${var.namespace}-rds"
    }
  )
}

resource "aws_db_instance" "this" {
  identifier_prefix = "${var.cluster_name}-${var.namespace}-"

  engine               = "postgres"
  engine_version       = var.db_engine_version
  instance_class       = var.db_instance_class
  allocated_storage    = var.db_allocated_storage
  storage_type         = "gp3"
  storage_encrypted    = true
  multi_az             = true
  publicly_accessible  = true

  db_name  = var.db_name
  username = var.db_master_username
  password = random_password.db_password.result
  port     = 5432

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.this.name

  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-${var.namespace}"
    }
  )
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name_prefix = "${var.cluster_name}/rds/${var.db_name}-"
  description = "RDS credentials for ${var.namespace}"

  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = aws_db_instance.this.username
    password = random_password.db_password.result
    endpoint = aws_db_instance.this.endpoint
    address  = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    database = aws_db_instance.this.db_name
  })
}

resource "kubernetes_secret" "db_credentials" {
  metadata {
    name      = "db-credentials"
    namespace = var.namespace
  }

  data = {
    username = aws_db_instance.this.username
    password = random_password.db_password.result
    endpoint = aws_db_instance.this.endpoint
    address  = aws_db_instance.this.address
    port     = tostring(aws_db_instance.this.port)
    database = aws_db_instance.this.db_name
  }

  depends_on = [helm_release.zitadel]
}