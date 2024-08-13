variable "toast_env" {
  description = "toast environment"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key to use for encryption"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
}

variable "lambda_timeout" {
  description = "Lambda function timeout"
  type        = number
  default     = 600
}

variable "lambda_memory_size" {
  description = "Lambda function memory size"
  type        = number
  default     = 2048
}

variable "lambda_storage" {
  description = "Lambda function ephemeral storage size"
  type        = number
  default     = 1024
}

# resources for ssm docs are not abstractable and must be regex arns...
variable "ssm_doc_resources" {
  description = "ssm document arns for list as resources in execution statement only"
  type        = list(string)
}