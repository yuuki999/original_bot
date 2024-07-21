variable "opensearch_domain_name" {
  type        = string
  description = "Name of the OpenSearch domain"
}

variable "opensearch_engine_version" {
  description = "Version of OpenSearch to deploy"
  type        = string
  default     = "OpenSearch_1.3"
}

variable "instance_type" {
  description = "Instance type for OpenSearch nodes"
  type        = string
  default     = "t3.small.search"
}

variable "instance_count" {
  description = "Number of instances in the OpenSearch domain"
  type        = number
  default     = 1
}

variable "zone_awareness_enabled" {
  description = "Enable zone awareness for the OpenSearch domain"
  type        = bool
  default     = false
}

variable "availability_zone_count" {
  description = "Number of availability zones for the OpenSearch domain"
  type        = number
  default     = 2
}

variable "volume_type" {
  description = "Type of EBS volumes attached to OpenSearch nodes"
  type        = string
  default     = "gp2"
}

variable "volume_size" {
  description = "Size of EBS volumes attached to OpenSearch nodes"
  type        = number
  default     = 10
}

variable "advanced_security_options_enabled" {
  description = "Enable advanced security options"
  type        = bool
  default     = true
}

variable "internal_user_database_enabled" {
  description = "Enable internal user database"
  type        = bool
  default     = true
}

variable "encrypt_at_rest_enabled" {
  description = "Enable encryption at rest"
  type        = bool
  default     = true
}

variable "node_to_node_encryption_enabled" {
  description = "Enable node-to-node encryption"
  type        = bool
  default     = true
}

variable "enforce_https" {
  description = "Enforce HTTPS for all traffic"
  type        = bool
  default     = true
}

variable "tls_security_policy" {
  description = "TLS security policy"
  type        = string
  default     = "Policy-Min-TLS-1-2-2019-07"
}

// VPCの設定
variable "vpc_options" {
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  description = "VPC options for OpenSearch domain"
}

variable "access_policies" {
  description = "IAM policy document specifying the access policies for the domain"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to the OpenSearch domain"
  type        = map(string)
  default     = {}
}

// ユーザー情報
variable "opensearch_username" {
  description = "OpenSearch username"
  type        = string
}

variable "opensearch_password" {
  description = "OpenSearch password"
  type        = string
  sensitive   = true // terraformのログ等に出力しないオプション
}

variable "lambda_role_arn" {
  type        = string
}

