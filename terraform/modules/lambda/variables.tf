variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "lambda_source_file" {
  description = "Path to the Lambda function source file"
  type        = string
}

variable "handler" {
  description = "Lambda function handler"
  type        = string
  default     = "index.handler"
}

variable "runtime" {
  description = "Lambda function runtime"
  type        = string
  default     = "nodejs20.x"
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket to grant access to"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to be applied to the Lambda function"
  type        = map(string)
  default     = {}
}

// VPC設定
variable "vpc_config" {
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  description = "VPC configuration for Lambda function"
}
