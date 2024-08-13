provider "aws" {
  region = "us-east-1"
}

terraform {
  required_version = "1.5.6"
  backend "s3" {
    bucket = "toast-tf-nonprod"
    key    = "prod/chase-key-rotate-v1.tfstate"
    region = "us-east-1"
    // comment this role_arn line out if you are using a read-only role
    role_arn = "arn:aws:iam::332176809242:role/prod-role-tf-applier"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}