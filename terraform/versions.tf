terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "okd-lab-tfstate"
    key            = "okd-prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true   # native S3 locking (Terraform >= 1.10); no DynamoDB table needed
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.cluster_name
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}
