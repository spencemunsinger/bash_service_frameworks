module "lambda_function_testing" {
  source = "../chase_h2h_key_rotate"
  toast_env = "prod"
  kms_key_arn = "arn:aws:kms:us-east-1:332176809242:key/4232b8bd-597e-424e-937d-d9f6761da7fd" # funds-transfer
  image_tag = "20240812132900"
  lambda_timeout = 600
  lambda_memory_size = 2048
  lambda_storage = 1024
  ssm_doc_resources = [
    "arn:aws:ssm:us-east-1:332176809242:document/ChaseH2HInvokeLambdaFunctionWithArgs*",
    "arn:aws:ssm:us-east-1:332176809242:automation-definition/ChaseH2HInvokeLambdaFunctionWithArgs*",
    "arn:aws:ssm:us-east-1:332176809242:automation-execution/*"
  ]
}