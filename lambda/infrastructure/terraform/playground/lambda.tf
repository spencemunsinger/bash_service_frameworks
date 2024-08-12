# IAM Role for Lambda Function
resource "aws_iam_role" "chase_h2h_key_rotate_lambda_docker" {
  name = "chase-h2h-key-rotate-lambda-docker"
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
  role       = aws_iam_role.chase_h2h_key_rotate_lambda_docker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "chase-h2h-lambda-exec-policy" {
  role       = aws_iam_role.chase_h2h_key_rotate_lambda_docker.name
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
  role       = aws_iam_role.chase_h2h_key_rotate_lambda_docker.name
  policy_arn = aws_iam_policy.chase-h2h-secretsmanager-policy.arn
}

# EC2 (network)

data "aws_iam_policy_document" "chase-h2h-ec2-policy-doc" {
    statement {
        actions = ["ec2:DescribeNetworkInterfaces",
                   "ec2:CreateNetworkInterface",
                   "ec2:DeleteNetworkInterface",
                   "ec2:DescribeSecurityGroups",
                   "ec2:DescribeSubnets",
                   "ec2:DescribeVpcs"
                   ]
        resources = ["*"]
    }
}

resource "aws_iam_policy" "chase-h2h-ec2-policy" {
    name = "chase-h2h-ec2-docker-policy"
    policy = data.aws_iam_policy_document.chase-h2h-ec2-policy-doc.json
}

# Attach the STS policy to the role
resource "aws_iam_role_policy_attachment" "chase-h2h-ec2-policy-attachment" {
    role = aws_iam_role.chase_h2h_key_rotate_lambda_docker.name
    policy_arn = aws_iam_policy.chase-h2h-ec2-policy.arn
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
    role = aws_iam_role.chase_h2h_key_rotate_lambda_docker.name
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
    role = aws_iam_role.chase_h2h_key_rotate_lambda_docker.name
    policy_arn = aws_iam_policy.chase-h2h-kms-policy.arn
}

# Lambda Function
resource "aws_lambda_function" "key_rotate_function" {
  function_name = "toast-chase-h2h-test-lambda-docker"
  role          = aws_iam_role.chase_h2h_key_rotate_lambda_docker.arn
  package_type  = "Image"
  image_uri     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/toast/toast-chase-test-lambda-docker:${var.image_tag}"
  timeout       = 600  # 10 minutes timeout
  memory_size   = 2048  # 1 GB memory
  ephemeral_storage {
    size = 1024  # Set the desired ephemeral storage size in MB
  }
  environment {
    variables = {
      TOAST_ENV = var.toast_env
    }
  }
  vpc_config {
      subnet_ids         = ["subnet-07114bdf5fdd4595e"]
      security_group_ids = [aws_security_group.lambda_sg.id]
  }  
}

# Security Group for Lambda Function
resource "aws_security_group" "lambda_sg" {
  name        = "lambda_sg"
  description = "Security group for Lambda function"
  vpc_id      = data.aws_vpc.aws_backspace_test.id

  # # Inbound rules (if needed)
  # ingress {
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "-1"
  #   cidr_blocks = ["10.4.0.0/16"]
  # }

  # Outbound rules (if needed)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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


# this would be the testing ECR only - ecr for preprod and prod are created through tf-import

# resource "aws_ecr_repository" "chase_test_lambda_docker_repo" {
#   name                 = "toast/toast-chase-test-lambda-docker"
#   image_tag_mutability = "MUTABLE"
#   image_scanning_configuration {
#     scan_on_push = true
#   }
# }