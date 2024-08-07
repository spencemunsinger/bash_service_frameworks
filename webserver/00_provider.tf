provider "aws" {
  region = "us-east-1"
}

terraform {
  required_version = "1.5.6"
  backend "s3" {
    bucket = "toast-tf-playground"
    key    = "playground/chase-h2h-lambda-docker-test-v1.tfstate"
    region = "us-east-1"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}