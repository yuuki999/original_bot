variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default     = {}
}

variable "allowed_ip" {
  type        = string
  description = "Allowed IP address for OpenSearch access"
}

variable "bation_ip" {
  type        = string
}
