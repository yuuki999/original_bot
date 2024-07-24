// クライアント VPN エンドポイントの作成
resource "aws_ec2_client_vpn_endpoint" "main" {
  description            = "document-processor-client-vpn"
  server_certificate_arn = var.server_certificate_arn // ACMの証明書ARN
  client_cidr_block      = "10.100.0.0/16" // VPCのCIDRと重複しない指定

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = var.server_certificate_arn // ACMの証明書ARN
  }

  connection_log_options {
    enabled              = true
    cloudwatch_log_group  = var.cloudwatch_log_group_name
    cloudwatch_log_stream = var.cloudwatch_log_stream_name
  }

  tags = var.common_tags
}

// クライアント VPN のターゲットネットワーク関連付け
resource "aws_ec2_client_vpn_network_association" "main" {
  count                  = length(var.subnet_ids)
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  subnet_id              = var.subnet_ids[count.index]

  depends_on = [aws_ec2_client_vpn_endpoint.main]
}

// クライアント VPN の認証ルール
resource "aws_ec2_client_vpn_authorization_rule" "main" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  target_network_cidr    = var.vpc_cidr
  authorize_all_groups   = true

  depends_on = [
    aws_ec2_client_vpn_endpoint.main,
    aws_ec2_client_vpn_network_association.main
  ]

  timeouts {
    create = "20m"
  }
}
