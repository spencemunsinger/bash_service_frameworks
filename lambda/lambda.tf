# IAM Role for Lambda Function
resource "aws_iam_role" "chase_h2h_test_lambda_docker" {
  name = "chase-h2h-test-lambda-docker"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# ECR

# Attach the AmazonEC2ContainerRegistryReadOnly policy to the role
resource "aws_iam_role_policy_attachment" "chase-h2h-ecr-read-only-policy" {
  role       = aws_iam_role.chase_h2h_test_lambda_docker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "chase-h2h-lambda-exec-policy" {
  role       = aws_iam_role.chase_h2h_test_lambda_docker.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# SECRETSMANAGER

# Define the Secrets Manager policy
data "aws_iam_policy_document" "chase-h2h-secretsmanager-policy-doc" {
  statement {
    actions = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:ListSecrets",
        "secretsmanager:ListSecretVersionIds",
        "secretsmanager:DescribeSecret",
        "secretsmanager:UpdateSecretVersionStage",
        "secretsmanager:PutSecretValue",
        "secretsmanager:CreateSecret",
        "secretsmanager:DeleteSecret",
        "secretsmanager:TagResource",
        "secretsmanager:UntagResource"
    ]
    resources = [
        "arn:aws:secretsmanager:us-east-1:${data.aws_caller_identity.current.account_id}:secret:${var.toast_env}/rsaKey/chasesftp-secret*",
        "arn:aws:secretsmanager:us-east-1:${data.aws_caller_identity.current.account_id}:secret:${var.toast_env}/rsaKey/chasesftp-public*",
        "arn:aws:secretsmanager:us-east-1:${data.aws_caller_identity.current.account_id}:secret:${var.toast_env}/rsaKey/chasesftp-host*",
        "arn:aws:secretsmanager:us-east-1:${data.aws_caller_identity.current.account_id}:secret:${var.toast_env}/rsaKey/chasepgp-secret*",
        "arn:aws:secretsmanager:us-east-1:${data.aws_caller_identity.current.account_id}:secret:${var.toast_env}/rsaKey/chasepgp-public*",
        "arn:aws:secretsmanager:us-east-1:${data.aws_caller_identity.current.account_id}:secret:${var.toast_env}/rsaKey/chasepgp-activate*"
    ]
  }
}

# Attach the Secrets Manager policy to the role
resource "aws_iam_policy" "chase-h2h-secretsmanager-policy" {
  name        = "chase-h2h-test-docker-lambda-secretsmanager-policy"
  description = "Policy for accessing Secrets Manager"
  policy      = data.aws_iam_policy_document.chase-h2h-secretsmanager-policy-doc.json
}

resource "aws_iam_role_policy_attachment" "chase-h2h-secretsmanager-policy-attachment" {
  role       = aws_iam_role.chase_h2h_test_lambda_docker.name
  policy_arn = aws_iam_policy.chase-h2h-secretsmanager-policy.arn
}

# STS

data "aws_iam_policy_document" "chase-h2h-sts-policy-doc" {
    statement {
        actions = ["sts:GetCallerIdentity"]
        resources = ["*"]
    }
}

resource "aws_iam_policy" "chase-h2h-sts-policy" {
    name = "chase-h2h-test-lambda-docker-sts-policy"
    policy = data.aws_iam_policy_document.chase-h2h-sts-policy-doc.json
}

# Attach the STS policy to the role
resource "aws_iam_role_policy_attachment" "chase-h2h-sts-policy-attachment" {
    role = aws_iam_role.chase_h2h_test_lambda_docker.name
    policy_arn = aws_iam_policy.chase-h2h-sts-policy.arn
}

# KMS

data "aws_iam_policy_document" "chase-h2h-kms-policy-doc" {
    statement {
        actions = ["kms:Decrypt",
                   "kms:Encrypt",
                   "kms:GenerateDataKey",
                   "kms:DescribeKey"]
        resources = ["${var.kms_key_arn}"]  
    }
}

resource "aws_iam_policy" "chase-h2h-kms-policy" {
    name = "chase-h2h-test-lambda-docker-kms-policy"
    policy = data.aws_iam_policy_document.chase-h2h-kms-policy-doc.json
}

resource "aws_iam_role_policy_attachment" "chase-h2h-kms-policy-attachment" {
    role = aws_iam_role.chase_h2h_test_lambda_docker.name
    policy_arn = aws_iam_policy.chase-h2h-kms-policy.arn
}

# Lambda Function
resource "aws_lambda_function" "key_rotate_function" {
  function_name = "toast-chase-h2h-test-lambda-docker"
  role          = aws_iam_role.chase_h2h_test_lambda_docker.arn
  package_type  = "Image"
  image_uri     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/toast/toast-chase-test-lambda-docker:${var.image_tag}"
  handler       = "function.handler"
  environment {
    variables = {
      # Add any environment variables required for your function here
      LAMBDA_ARG1 = "environment"
      LAMBDA_ARG2 = "switch_1"
      LAMBDA_ARG3 = "switch_2"
    }
  }
}

# # IAM Role for Engineer to Assume Lambda Role
# resource "aws_iam_role" "engineer_role" {
#   name = "engineer_role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Principal = {
#           AWS = "arn:aws:iam::123456789012:user/engineer"  # Replace with the engineer's IAM user ARN
#         },
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })
# }

# # Policy for Engineer to Invoke Lambda Function
# resource "aws_iam_policy" "invoke_lambda_policy" {
#   name        = "invoke_lambda_policy"
#   description = "Policy for Engineer to Invoke Lambda Function"
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = "lambda:InvokeFunction",
#         Resource = aws_lambda_function.key_rotate_function.arn
#       }
#     ]
#   })
# }

# # Attach Policy to Engineer Role
# resource "aws_iam_role_policy_attachment" "engineer_invoke_policy_attach" {
#   role       = aws_iam_role.engineer_role.name
#   policy_arn = aws_iam_policy.invoke_lambda_policy.arn
# }

resource "aws_ecr_repository" "chase_test_lambda_docker_repo" {
  name                 = "toast/toast-chase-test-lambda-docker"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}