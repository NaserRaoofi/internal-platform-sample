# Development Environment Terraform Configuration
# This file manages all resources for the development environment

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure AWS Provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = "development"
      Project     = "internal-developer-platform"
      ManagedBy   = "terraform"
    }
  }
}

# Local values for development environment
locals {
  environment = "dev"
  common_tags = {
    Environment = local.environment
    Project     = "internal-developer-platform"
    ManagedBy   = "terraform"
  }
}
