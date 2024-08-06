output "function_arn" {
  description = "The ARN of the Lambda function"
  value       = aws_lambda_function.document_processor.arn
}

output "function_name" {
  description = "The name of the Lambda function"
  value       = aws_lambda_function.document_processor.function_name
}

output "role_arn" {
  description = "The ARN of the IAM role created for the Lambda function"
  value       = aws_iam_role.lambda_role.arn
}
