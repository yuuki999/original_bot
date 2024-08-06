# Lambda関数のソースファイルパス
variable "lambda_source_file" {
  description = "Path to the Lambda function source file"
  type        = string
}

# Lambda関数名
variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

# VPC設定
variable "vpc_config" {
  description = "VPC configuration for the Lambda function"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
}

# タグ
variable "tags" {
  description = "Tags to be applied to the Lambda function"
  type        = map(string)
  default     = {}
}

# Bedrockエンドポイント
variable "bedrock_endpoint" {
  description = "Endpoint URL for Bedrock service"
  type        = string
}

# OpenSearchエンドポイント
variable "opensearch_endpoint" {
  description = "Endpoint URL for OpenSearch service"
  type        = string
}

# OpenSearchユーザー名
variable "opensearch_username" {
  description = "Username for OpenSearch service"
  type        = string
}

# OpenSearchパスワード
variable "opensearch_password" {
  description = "Password for OpenSearch service"
  type        = string
  sensitive   = true
}

# OpenSearchドメインARN
variable "opensearch_domain_arn" {
  description = "ARN of the OpenSearch domain"
  type        = string
}

# Lambda関数のタイムアウト（秒）
variable "timeout" {
  description = "The amount of time your Lambda Function has to run in seconds"
  type        = number
  default     = 3
}

# Lambda関数のメモリサイズ（MB）
variable "memory_size" {
  description = "Amount of memory in MB your Lambda Function can use at runtime"
  type        = number
  default     = 128
}

# Lambda関数のランタイム
variable "runtime" {
  description = "The runtime environment for the Lambda function"
  type        = string
  default     = "nodejs18.x"
}

variable "bedrock_model_id" {
  description = "The ID of the Bedrock model to use"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20240620-v1:0"
}

# OpenSearch Index
variable "opensearch_index" {
  description = "The name of the OpenSearch index to use"
  type        = string
}

# Bedrock Max Tokens
variable "bedrock_max_tokens" {
  description = "The maximum number of tokens for Bedrock to generate"
  type        = number
  default     = 1000
}
