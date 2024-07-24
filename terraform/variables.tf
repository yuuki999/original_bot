// 変数を定義するが値の実態はterraform.tfvarsに定義されたものが使用される。
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "opensearch_document_bucket_name" {
  description = "Name of the S3 bucket for document storage"
  type        = string
}

variable "opensearch_domain_name" {
  type        = string
  description = "Name of the OpenSearch domain"
}

variable "opensearch_engine_version" {
  description = "Version of OpenSearch to deploy"
  type        = string
  default     = "OpenSearch_1.3"
}

variable "opensearch_instance_type" {
  description = "Instance type for OpenSearch domain"
  type        = string
  default     = "t3.small.search"
}

variable "opensearch_instance_count" {
  description = "Number of instances in the OpenSearch domain"
  type        = number
  default     = 1
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "lambda_runtime" {
  description = "Runtime of the Lambda function"
  type        = string
}

variable "lambda_handler" {
  description = "Handler of the Lambda function"
  type        = string
}

variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default     = {}
}

variable "aws_profile" {
  description = "AWS credentials profile to use"
  type        = string
  default     = "dev"
}

# variable "vpc_subnet_ids" {
#   type        = list(string)
#   description = "List of VPC Subnet IDs for the OpenSearch domain"
# }

# variable "vpc_security_group_ids" {
#   type        = list(string)
#   description = "List of VPC Security Group IDs for the OpenSearch domain"
# }

variable "doppler_token" {
  type        = string
  description = "Doppler API token"
}

variable "allowed_ip" {
  type        = string
  description = "Allowed IP address for OpenSearch access"
}

variable "allowed_iam_arn" {
  type        = string
}

variable "certificate_arn" {
  type        = string
}
