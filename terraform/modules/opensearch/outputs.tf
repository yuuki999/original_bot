output "domain_id" {
  description = "ID of the OpenSearch domain"
  value       = aws_opensearch_domain.domain.domain_id
}

output "domain_name" {
  description = "Name of the OpenSearch domain"
  value       = aws_opensearch_domain.domain.domain_name
}

output "domain_endpoint" {
  description = "Domain-specific endpoint used to submit index, search, and data upload requests"
  value       = aws_opensearch_domain.domain.endpoint
}

output "arn" {
  description = "ARN of the OpenSearch domain"
  value       = aws_opensearch_domain.domain.arn
}

output "endpoint" {
  value = "https://${aws_opensearch_domain.domain.endpoint}"
}

