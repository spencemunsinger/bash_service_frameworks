# LAMBDA (all environments)

# lambda function
resource "aws_lambda_function" "key_rotate_function" {
  function_name = "toast-chase-h2h-test-lambda-docker"
  role          = aws_iam_role.chase_h2h_test_lambda_docker.arn
  package_type  = "Image"
  image_uri     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/toast/toast-chase-test-lambda-docker:${var.image_tag}"
  timeout       = var.lambda_timeout  # 10 minutes timeout
  memory_size   = var.lambda_memory_size  # 2 GB memory
  ephemeral_storage {
    size = var.lambda_storage  # Set the desired ephemeral storage size in MB
  }
  environment {
    variables = {
      TOAST_ENV = var.toast_env
    }
  }
  # conditional VPC configuration, if playground for transmisison testing
  dynamic "vpc_config" {
    for_each = var.toast_env == "playground" ? [1] : []
    content {
      subnet_ids         = ["subnet-07114bdf5fdd4595e"]
      security_group_ids = [aws_security_group.lambda_sg.id]
    }
  }
}

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

# attach AWSLambdaBasicExecutionRole policy to the lambda role
resource "aws_iam_role_policy_attachment" "chase-h2h-lambda-exec-policy" {
  role       = aws_iam_role.chase_h2h_test_lambda_docker.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# ECR policy (all environments)

# Attach the AmazonEC2ContainerRegistryReadOnly policy to the lambda role
resource "aws_iam_role_policy_attachment" "chase-h2h-ecr-read-only-policy" {
  role       = aws_iam_role.chase_h2h_test_lambda_docker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# SECRETSMANAGER policy (all environments)

# Define the secretsmanager policy
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
# policy for secretsmanager
resource "aws_iam_policy" "chase-h2h-secretsmanager-policy" {
  name        = "chase-h2h-test-docker-lambda-secretsmanager-policy"
  description = "Policy for accessing Secrets Manager"
  policy      = data.aws_iam_policy_document.chase-h2h-secretsmanager-policy-doc.json
}
# policy attachment for secretsmanager
resource "aws_iam_role_policy_attachment" "chase-h2h-secretsmanager-policy-attachment" {
  role       = aws_iam_role.chase_h2h_test_lambda_docker.name
  policy_arn = aws_iam_policy.chase-h2h-secretsmanager-policy.arn
}

# EC2 (network policy) (playground)

# define the ec2 policy, needed for network interface creation if playground and attached to vpc for testing
data "aws_iam_policy_document" "chase-h2h-ec2-policy-doc" {
    count = var.toast_env == "playground" ? 1 : 0
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
# ec2 policy create
resource "aws_iam_policy" "chase-h2h-ec2-policy" {
    count = var.toast_env == "playground" ? 1 : 0
    name = "chase-h2h-ec2-docker-policy"
    policy = data.aws_iam_policy_document.chase-h2h-ec2-policy-doc[count.index].json
}
# Attach the ec2 policy to the role
resource "aws_iam_role_policy_attachment" "chase-h2h-ec2-policy-attachment" {
    count = var.toast_env == "playground" ? 1 : 0
    role = aws_iam_role.chase_h2h_test_lambda_docker.name
    policy_arn = aws_iam_policy.chase-h2h-ec2-policy[count.index].arn
}

# STS (all environments)

# policy document for sts
data "aws_iam_policy_document" "chase-h2h-sts-policy-doc" {
    statement {
        actions = ["sts:GetCallerIdentity"]
        resources = ["*"]
    }
}
# policy for sts
resource "aws_iam_policy" "chase-h2h-sts-policy" {
    name = "chase-h2h-test-lambda-docker-sts-policy"
    policy = data.aws_iam_policy_document.chase-h2h-sts-policy-doc.json
}
# Attach the sts policy to the role
resource "aws_iam_role_policy_attachment" "chase-h2h-sts-policy-attachment" {
    role = aws_iam_role.chase_h2h_test_lambda_docker.name
    policy_arn = aws_iam_policy.chase-h2h-sts-policy.arn
}

# KMS (all environments)

# policy document for kms
data "aws_iam_policy_document" "chase-h2h-kms-policy-doc" {
    statement {
        actions = ["kms:Decrypt",
                   "kms:Encrypt",
                   "kms:GenerateDataKey",
                   "kms:DescribeKey"]
        resources = ["${var.kms_key_arn}"]  
    }
}
# policy for kms
resource "aws_iam_policy" "chase-h2h-kms-policy" {
    name = "chase-h2h-test-lambda-docker-kms-policy"
    policy = data.aws_iam_policy_document.chase-h2h-kms-policy-doc.json
}
# attach the kms policy to the role
resource "aws_iam_role_policy_attachment" "chase-h2h-kms-policy-attachment" {
    role = aws_iam_role.chase_h2h_test_lambda_docker.name
    policy_arn = aws_iam_policy.chase-h2h-kms-policy.arn
}

# SECURITY GROUP (playground only)

# security group for lambda function if playground and attached to vpc for testing
# this is required to attach lambda to VPC
resource "aws_security_group" "lambda_sg" {
  count       = var.toast_env == "playground" ? 1 : 0
  name        = "lambda_sg"
  description = "Security group for Lambda function"
  vpc_id      = data.aws_vpc.aws_backspace_test.id
  # Outbound rules (if needed)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECR repo (playground only)

# Conditional ECR Repository Creation - create repo if playground env
resource "aws_ecr_repository" "chase_test_lambda_docker_repo" {
  count                = var.toast_env == "playground" ? 1 : 0
  name                 = "toast/toast-chase-test-lambda-docker"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
}