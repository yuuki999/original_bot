output "s3_bucket_name" {
  description = "Name of the created S3 bucket"
  value       = module.s3_bucket.bucket_id
}

output "lambda_function_name" {
  description = "Name of the created Lambda function"
  value       = module.lambda_function.function_name
}

output "opensearch_domain_endpoint" {
  description = "Endpoint of the created OpenSearch domain"
  value       = module.opensearch_domain.domain_endpoint
}

output "opensearch_kibana_endpoint" {
  description = "Kibana endpoint of the created OpenSearch domain"
  value       = module.opensearch_domain.dashboard_endpoint
}
