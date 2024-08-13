variable "toast_env" {
  description = "toast environment"
  type        = string
  default     = "preproduction"
}

variable "kms_key_arn" {
  description = "KMS key to use for encryption"
  type        = string
  default     = "arn:aws:kms:us-east-1:620354051118:key/b28396ec-8900-477f-a0dc-19db378c0f65" # funds-transfer 
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  #default     = "refined"
  default     = "20240812131500"
}
