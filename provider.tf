terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.27.0, < 7.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.60.0, < 2.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "s3" {}
}

locals {
  default_tags = {
    Project     = "aws-amazon-connect-contact-center"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
}

# Amazon Connect, Amazon Lex V2, Lambda and DynamoDB are all offered in af-south-1, so this stack needs no Ireland
# alias. Amazon Q in Connect and Voice ID are not offered in Cape Town and are therefore not part of the stack
# (docs/regional-availability.md).
provider "aws" {
  region = var.primary_region

  default_tags {
    tags = local.default_tags
  }
}

provider "awscc" {
  region = var.primary_region
}
