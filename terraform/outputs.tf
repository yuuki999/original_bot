output "s3_bucket_name" {
  description = "Name of the created S3 bucket"
  value       = module.s3_bucket.bucket_id
}

output "opensearch_lambda" {
  description = "Name of the created Lambda function"
  value       = module.opensearch_lambda.function_name
}

output "opensearch_domain_endpoint" {
  description = "Endpoint of the created OpenSearch domain"
  value       = module.opensearch_domain.domain_endpoint
}

output "opensearch_kibana_endpoint" {
  description = "Kibana endpoint of the created OpenSearch domain"
  value       = module.opensearch_domain.endpoint
}
