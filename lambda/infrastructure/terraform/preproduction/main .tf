module "lambda_function" {
  source = "../chase_h2h_key_rotate"
  toast_env = "preproduction"
  kms_key_arn = "arn:aws:kms:us-east-1:620354051118:key/b28396ec-8900-477f-a0dc-19db378c0f65" # funds-transfer 
  image_tag = "20240812132900"
  lambda_timeout = 600
  lambda_memory_size = 2048
  lambda_storage = 1024
  ssm_doc_resources = [
    "arn:aws:ssm:us-east-1:620354051118:document/ChaseH2HInvokeLambdaFunctionWithArgs*",
    "arn:aws:ssm:us-east-1:620354051118:automation-definition/ChaseH2HInvokeLambdaFunctionWithArgs*",
    "arn:aws:ssm:us-east-1:620354051118:automation-execution/*"
  ]
}