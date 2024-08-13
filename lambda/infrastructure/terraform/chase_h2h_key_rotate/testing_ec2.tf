## EC 2 test instan ce - playground testing only

# just an instance...
resource "aws_instance" "ec2" {
  count             = var.toast_env == "playground" ? 1 : 0
  #ami                    = "ami-087ae2c33ef6846c9"   # ubuntu 22.04 AWS AMI
  ami                    = "ami-05b22abcfb7abfb1d" # with docker preinstalled
  instance_type          = "t2.medium"
  subnet_id              = aws_subnet.az1-outside[count.index].id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.sg[count.index].id]
  key_name               = "dsm_aws_course"  # Replace with your actual key pair name
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile[count.index].name
  tags = {
    Name = "chase-h2h-test-instance"
    toast_environment  = "${var.toast_env}"
    toast_service_name = "aws-backspace"
  }
  metadata_options {
    http_tokens                 = "optional"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }
}

# Create an IAM role
resource "aws_iam_role" "ec2_role" {
  count             = var.toast_env == "playground" ? 1 : 0
  name = "chase-h2h-test-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# attach the ecr read-only policy - AmazonEC2ContainerRegistryReadOnly - to the role
resource "aws_iam_role_policy_attachment" "ecr_read_only_policy" {
  count             = var.toast_env == "playground" ? 1 : 0
  role       = aws_iam_role.ec2_role[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# attach the secretsmanager policy to the role
resource "aws_iam_role_policy_attachment" "secrets_manager_policy_attachment" {
  count             = var.toast_env == "playground" ? 1 : 0
  role       = aws_iam_role.ec2_role[count.index].name
  policy_arn = aws_iam_policy.chase-h2h-secretsmanager-policy.arn
}

# attach the STS policy to the role
resource "aws_iam_role_policy_attachment" "sts_policy_attachment" {
  count             = var.toast_env == "playground" ? 1 : 0
  role       = aws_iam_role.ec2_role[count.index].name
  policy_arn = aws_iam_policy.chase-h2h-sts-policy.arn
}

# Attach the kms policy to the role
resource "aws_iam_role_policy_attachment" "kms_policy_attachment" {
  count             = var.toast_env == "playground" ? 1 : 0
    role = aws_iam_role.ec2_role[count.index].name
    policy_arn = aws_iam_policy.chase-h2h-kms-policy.arn
}

# ecr writing policy document
data "aws_iam_policy_document" "ec2_ecr_policy" {
  count             = var.toast_env == "playground" ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = [
      "arn:aws:ecr:us-east-1:676018146487:repository/toast/toast-chase-test-lambda-docker"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages"
    ]
    resources = ["*"]
  }
}
# ecr policy
resource "aws_iam_policy" "ec2_ecr_upload_policy" {
  count             = var.toast_env == "playground" ? 1 : 0
  name        = "ECRUploadPolicy"
  description = "Policy to allow uploading Docker images to ECR"
  policy      = data.aws_iam_policy_document.ec2_ecr_policy[count.index].json
}
# attach the ecr policy to the role
resource "aws_iam_role_policy_attachment" "attach_ecr_upload_policy" {
  count             = var.toast_env == "playground" ? 1 : 0
  role       = aws_iam_role.ec2_role[count.index].name
  policy_arn = aws_iam_policy.ec2_ecr_upload_policy[count.index].arn
}

# Create the IAM instance profile from the role
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  count             = var.toast_env == "playground" ? 1 : 0
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_role[count.index].name
}

## SECURITY GROUP for ec2 instance (testing only)

resource "aws_security_group" "sg" {
  count       = var.toast_env == "playground" ? 1 : 0
  name        = "chase-h2h-sg-test"
  description = "${var.toast_env} terraform interview"
  vpc_id      = aws_vpc.main[count.index].id
  tags = {
    Name = "chase-h2h-sg-test"
    toast_environment  = "${var.toast_env}"
    toast_service_name = "chase-h2h-key-rotate"
  }
  ingress {
    description = "Allow SSH traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.4.0.0/16"]  # developer IPs can be added here plus VPC CIDR
  }
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
