resource "aws_opensearch_domain" "domain" {
  domain_name    = var.opensearch_domain_name
  engine_version = var.opensearch_engine_version

  // インスタンスの設定
  cluster_config {
    instance_type          = var.instance_type
    instance_count         = var.instance_count
    zone_awareness_enabled = var.zone_awareness_enabled

    dynamic "zone_awareness_config" {
      for_each = var.zone_awareness_enabled ? [1] : []
      content {
        availability_zone_count = var.availability_zone_count
      }
    }
  }

  // EBSの設定
  ebs_options {
    ebs_enabled = true
    volume_type = var.volume_type
    volume_size = var.volume_size
  }

  // セキュリティオプション
  advanced_security_options {
    enabled                        = var.advanced_security_options_enabled // falseにしてIAM ベースの認証とアクセス制御のみとする。
    internal_user_database_enabled = var.internal_user_database_enabled
    # master_user_options { // lambdaがIAM認証を使用する場合は不要になる可能性がある。
    #   master_user_arn = aws_iam_role.lambda_role.arn
    # }
  }

  // OpenSearchの暗号化設定
  encrypt_at_rest {
    enabled = var.encrypt_at_rest_enabled
  }
  node_to_node_encryption {
    enabled = var.node_to_node_encryption_enabled
  }

  // HTTPSの強制とTLSセキュリティポリシーを設定
  domain_endpoint_options {
    enforce_https       = var.enforce_https
    tls_security_policy = var.tls_security_policy
  }

  // VPCオプション、lambdaと通信できるようにするために必要
  vpc_options {
    subnet_ids         = var.vpc_options.subnet_ids
    security_group_ids = var.vpc_options.security_group_ids
  }

  // リソースベースのポリシー
  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            var.lambda_role_arn,
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.allowed_iam_arn}"
          ]
        }
        Action = "es:*"
        // ここでaws_opensearch_domain.domain.arnを使うと、リソースが作成される前に参照しようとしてエラーになる。なのでdataを使う。
        Resource = "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.opensearch_domain_name}/*"
      }
    ]
  })

  tags = var.tags
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
