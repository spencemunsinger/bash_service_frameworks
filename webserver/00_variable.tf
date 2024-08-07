variable "toast_env" {
  description = "toast environment"
  type        = string
  default     = "playground"
}

variable "kms_key_arn" {
  description = "KMS key to use for encryption"
  type        = string
  default     = "arn:aws:kms:us-east-1:676018146487:key/53fd7a19-891a-45d0-8e54-9b844e3d47d3" 
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "refined"
}
