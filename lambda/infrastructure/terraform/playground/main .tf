module "lambda_function_testing" {
  source = "../chase_h2h_key_rotate"
  toast_env = "playground"
  kms_key_arn = "arn:aws:kms:us-east-1:676018146487:key/53fd7a19-891a-45d0-8e54-9b844e3d47d3"
  image_tag = "20240812132900"
  lambda_timeout = 600
  lambda_memory_size = 2048
  lambda_storage = 1024
  ssm_doc_resources = [
    "arn:aws:ssm:us-east-1:676018146487:document/ChaseH2HInvokeLambdaFunctionWithArgs*",
    "arn:aws:ssm:us-east-1:676018146487:automation-definition/ChaseH2HInvokeLambdaFunctionWithArgs*",
    "arn:aws:ssm:us-east-1:676018146487:automation-execution/*"
  ]
}