output "vpn_log_group_name" {
  value       = aws_cloudwatch_log_group.vpn_logs.name
  description = "Name of the CloudWatch Log Group for VPN connection logs"
}

output "vpn_log_stream_name" {
  value       = aws_cloudwatch_log_stream.vpn_log_stream.name
  description = "Name of the CloudWatch Log Stream for VPN connection logs"
}
