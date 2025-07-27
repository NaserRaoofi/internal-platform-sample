
# Generated Terraform configuration for request 0610dfe5-b4ae-4eb0-b473-bec0e33098df
# Resource type: s3

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
}

# Use the s3 module
module "s3_instance" {
  source = "../../s3"
  bucket_name = "sirwan234-v"
  versioning_enabled = false
  encryption_enabled = false
  public_read_access = true
  lifecycle_rules = []
  tags = {"Environment": "dev"}

}

# Output all module outputs
output "resource_outputs" {
  description = "All outputs from the resource module"
  value       = module.s3_instance
}
