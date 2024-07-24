// ACMでサーバー(パブリック)証明書の発行
# resource "aws_acm_certificate" "server" {
#   domain_name       = "yuki-engineer.com"
#   validation_method = "DNS"

#   tags = var.common_tags

#   lifecycle {
#     create_before_destroy = true // すでに存在するリソースを削除する前に新しいリソースを作成する
#   }
# }

# // ACM証明書の検証プロセスを管理
# resource "aws_acm_certificate_validation" "server" {
#   certificate_arn         = aws_acm_certificate.server.arn // 検証する証明書のARN
#   validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn] // 検証に使用するDNSレコードのFQDNリストを指定
#   depends_on = [aws_route53_record.cert_validation]

#   // Route 53を使う理由
#   // DNS検証：ACMは証明書の発行前に、あなたがドメインの所有者であることを確認する必要があります。
#   // 自動化：Route 53を使用すると、証明書検証用のDNSレコードを自動的に作成・管理できます。
# }

# // Route 53のホストゾーンを作成
# resource "aws_route53_zone" "main" {
#   name = "yuki-engineer.com"
# }

# // 証明書検証用のRoute 53レコードを作成
# resource "aws_route53_record" "cert_validation" {
#   for_each = {
#     for dvo in aws_acm_certificate.server.domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       record = dvo.resource_record_value
#       type   = dvo.resource_record_type
#     }
#   }

#   allow_overwrite = true
#   name            = each.value.name
#   records         = [each.value.record]
#   ttl             = 60
#   type            = each.value.type
#   zone_id         = aws_route53_zone.main.zone_id

#   depends_on = [aws_acm_certificate.server]
# }
