terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "much-to-do-tfstate-bucket-dale"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "much-to-do-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}
