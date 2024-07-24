resource "aws_cloudwatch_log_group" "vpn_logs" {
  name              = "ClientVpnConnectionLogs"
  retention_in_days = 30  # ログの保持期間を30日に設定

  tags = var.common_tags
}

resource "aws_cloudwatch_log_stream" "vpn_log_stream" {
  name           = "DocumentProcessorClientVpn"
  log_group_name = aws_cloudwatch_log_group.vpn_logs.name
}
