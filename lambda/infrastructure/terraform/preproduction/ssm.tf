resource "aws_ssm_document" "chase_h2h_invoke_lambda_ssm_document" {
  name          = "ChaseH2HInvokeLambdaFunctionWithArgs"
  document_type = "Automation"
  content       = jsonencode({
    schemaVersion = "0.3",
    description   = "Document to invoke Lambda function with a single args parameter",
    parameters    = {
      LambdaFunctionName = {
        type        = "String"
        description = "Name of the Lambda function to invoke"
        default = "${aws_lambda_function.key_rotate_function.function_name}"
      },
      args = {
        type        = "String"
        description = "Command-line arguments to pass to the Lambda function"
      }
    },
    mainSteps = [
      {
        action = "aws:invokeLambdaFunction"
        name   = "invokeLambda"
        inputs = {
          FunctionName = "{{ LambdaFunctionName }}"
          InputPayload = {
            args = "{{ args }}"
          }
        }
      }
    ]
  })
}

# Policy for Accessing SSM Document and Invoking Lambda

data "aws_iam_policy_document" "chase_h2h_ssm_lambda_invoke_policy_doc" {
  statement {
    effect  = "Allow"
    condition {
      test     = "IpAddress"
      variable = "aws:VpcSourceIp"
      values   = ["172.19.0.0/16"]
    }
    actions = [
      "ssm:StartAutomationExecution",
      "ssm:GetAutomationExecution",
      "lambda:InvokeFunction"
    ]
    resources = [
      aws_ssm_document.chase_h2h_invoke_lambda_ssm_document.arn,
      aws_lambda_function.key_rotate_function.arn
    ]
  }
}

resource "aws_iam_policy" "chase_h2h_ssm_lambda_invoke_policy" {
  name   = "chase_h2h_key_rotate_ssm_lambda_invoke_policy"
  policy = data.aws_iam_policy_document.chase_h2h_ssm_lambda_invoke_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "chase_h2h_ssm_lambda_invoke_policy_attachment" {
  role       = aws_iam_role.toast_user_chase_h2h_key_rotate_lambda_ssm_payments.name # this will be created in tf-import as an okta role
  policy_arn = aws_iam_policy.chase_h2h_ssm_lambda_invoke_policy.arn
}

## everything below here will be in tf-import

# # add access to ssm kms key...check
# # https://github.toasttab.com/toasttab/tf-import/blob/60bd164e1123333d155b23ce51de089f76cf76c3/envs-core/preproduction/kms/ssm.tf
  
# # okta assume role for playground env
# data "aws_iam_policy_document" "chase_h2h_assume_role_policy" {
#   statement {
#     effect  = "Allow"
#     actions = ["sts:AssumeRoleWithSAML"]
#     condition {
#       test     = "StringEquals"
#       variable = "SAML:aud"
#       values   = ["https://signin.aws.amazon.com/saml"]
#     }
#     principals {
#       type        = "Federated"
#       identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:saml-provider/okta"]
#     }
#   }
#   statement {
#     effect  = "Allow"
#     actions = ["sts:TagSession"]
#     principals {
#       type        = "Federated"
#       identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:saml-provider/okta"]
#     }
#   }
# }

# resource "aws_iam_role" "toast_user_chase_h2h_key_rotate_lambda_ssm_payments" {
#   name        = "toast-role-user-chase-h2h-key-rotate-lambda-ssm-payments"
#   description = "role to allow toast user to assume role to invoke chase h2h key rotate lambda function"

#   assume_role_policy = data.aws_iam_policy_document.chase_h2h_assume_role_policy.json
# }

