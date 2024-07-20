// 親モジュールと重複した場合は、優先順位は低く、オーバーライドされる。
variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "bucket_acl" {
  description = "ACL for the S3 bucket"
  type        = string
  default     = "private"
}

variable "enable_versioning" {
  description = "Enable versioning for the S3 bucket"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to be applied to the S3 bucket"
  type        = map(string)
  default     = {}
}
