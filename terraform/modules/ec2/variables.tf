
variable "vpc_security_group_ids" {
  type        = string
}

variable "public_subnet_id" {
  type        = string
}

variable "public_key_path" {
  description = "Path to the public key file for SSH access"
  type        = string
}


