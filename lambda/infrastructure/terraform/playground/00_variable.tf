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
  #default     = "refined"
  default     = "20240812132900"
}

variable "ssm_doc_resources" {
  description = "ssm document arns for list as resources"
  type        = list(string)
  default     = [
    "arn:aws:ssm:us-east-1:676018146487:document/ChaseH2HInvokeLambdaFunctionWithArgs*",
    "arn:aws:ssm:us-east-1:676018146487:automation-definition/ChaseH2HInvokeLambdaFunctionWithArgs*",
    "arn:aws:ssm:us-east-1:676018146487:automation-execution/*"
  ]
}