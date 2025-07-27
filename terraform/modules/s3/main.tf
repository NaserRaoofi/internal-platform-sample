# S3 Bucket Terraform Module

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Input Variables
variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "versioning_enabled" {
  description = "Enable versioning on the bucket"
  type        = bool
  default     = false
}

variable "encryption_enabled" {
  description = "Enable server-side encryption"
  type        = bool
  default     = true
}

variable "public_read_access" {
  description = "Allow public read access to bucket"
  type        = bool
  default     = false
}

variable "lifecycle_rules" {
  description = "List of lifecycle rules"
  type = list(object({
    id     = string
    status = string
    filter = object({
      prefix = string
    })
    expiration = object({
      days = number
    })
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# S3 Bucket
resource "aws_s3_bucket" "main" {
  bucket = "${var.bucket_name}-${random_id.bucket_suffix.hex}"

  tags = merge(var.tags, {
    Name = "${var.bucket_name}-${random_id.bucket_suffix.hex}"
  })
}

# Bucket Versioning
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# Bucket Server-side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  count  = var.encryption_enabled ? 1 : 0
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block Public Access (unless explicitly allowed)
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = var.public_read_access ? false : true
  block_public_policy     = var.public_read_access ? false : true
  ignore_public_acls      = var.public_read_access ? false : true
  restrict_public_buckets = var.public_read_access ? false : true
}

# Bucket Policy for Public Read Access (if enabled)
resource "aws_s3_bucket_policy" "public_read" {
  count  = var.public_read_access ? 1 : 0
  bucket = aws_s3_bucket.main.id
  
  depends_on = [aws_s3_bucket_public_access_block.main]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.main.arn}/*"
      }
    ]
  })
}

# Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.main.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.status

      filter {
        prefix = rule.value.filter.prefix
      }

      expiration {
        days = rule.value.expiration.days
      }
    }
  }
}

# Random suffix for unique bucket naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Outputs
output "bucket_name" {
  description = "Name of the created S3 bucket"
  value       = aws_s3_bucket.main.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.main.arn
}

output "bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.main.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.main.bucket_regional_domain_name
}

output "bucket_hosted_zone_id" {
  description = "Hosted zone ID of the S3 bucket"
  value       = aws_s3_bucket.main.hosted_zone_id
}
