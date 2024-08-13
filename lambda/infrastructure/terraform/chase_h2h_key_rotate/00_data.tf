data "aws_caller_identity" "current" {
}

# playground only
data "aws_vpc" "aws_backspace_test" {
  tags = {
    Name = "aws-backspace-test"
  }
}

