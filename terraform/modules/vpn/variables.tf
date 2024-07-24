variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group for VPN connection logs"
  type        = string
}

variable "cloudwatch_log_stream_name" {
  description = "Name of the CloudWatch Log Stream for VPN connection logs"
  type        = string
}

variable "server_certificate_arn" {
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block of the VPC"
  type        = string
}

