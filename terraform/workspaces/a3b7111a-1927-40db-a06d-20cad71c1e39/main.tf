# Sirwan Test Template - S3 Bucket with Advanced Configuration + Optional EC2
# Cost: $0.50-15.00/month (depending on usage and EC2 instance)
# Components: S3 bucket with versioning, encryption, lifecycle management, and optional EC2 instance

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Random suffix for unique resource names
resource "random_id" "test_suffix" {
  byte_length = 4
}

# Local values for consistent naming and tagging
locals {
  bucket_id = "${var.bucket_name}-${random_id.test_suffix.hex}"
  
  common_tags = merge(var.tags, {
    Name        = local.bucket_id
    BucketName  = var.bucket_name
    Environment = var.environment
    Template    = "sirwan-test"
    ManagedBy   = "terraform"
    Owner       = "sirwan"
    Purpose     = var.bucket_purpose
    CreatedBy   = "internal-developer-platform"
    CreatedAt   = timestamp()
  })
}

# Primary S3 Bucket using the existing aws-s3 module
module "main_bucket" {
  source = "../../modules/aws-s3"
  
  bucket_name       = local.bucket_id
  use_random_suffix = false  # We're already adding suffix above
  environment       = var.environment
  bucket_purpose    = var.bucket_purpose
  
  # Security configuration
  versioning_enabled = var.versioning_enabled
  encryption_enabled = var.encryption_enabled
  public_read_access = var.public_read_access
  force_destroy     = var.force_destroy
  
  # Website configuration (if enabled)
  website_enabled         = var.website_enabled
  website_index_document  = var.website_index_document
  website_error_document  = var.website_error_document
  website_routing_rules   = var.website_routing_rules
  
  # CORS configuration
  cors_rules = var.cors_enabled ? [
    {
      allowed_methods = var.cors_allowed_methods
      allowed_origins = var.cors_allowed_origins
      allowed_headers = var.cors_allowed_headers
      expose_headers  = var.cors_expose_headers
      max_age_seconds = var.cors_max_age_seconds
    }
  ] : []
  
  # Lifecycle management for cost optimization
  lifecycle_rules = var.lifecycle_enabled ? [
    {
      id      = "sirwan_test_lifecycle"
      enabled = true
      filter = {
        prefix = var.lifecycle_prefix
        tags   = var.lifecycle_tags
      }
      transitions = var.lifecycle_transitions
      expiration = var.lifecycle_expiration
      noncurrent_version_expiration = var.lifecycle_noncurrent_expiration
      noncurrent_version_transitions = var.lifecycle_noncurrent_transitions
    }
  ] : []
  
  # Notification configuration
  notification_enabled = var.notification_enabled
  lambda_notifications = var.lambda_notifications
  sns_notifications   = var.sns_notifications
  sqs_notifications   = var.sqs_notifications
  
  # KMS encryption
  kms_key_id = var.kms_key_id
  
  tags = local.common_tags
}

# Optional: Additional S3 bucket for backups (if backup is enabled)
module "backup_bucket" {
  count  = var.backup_enabled ? 1 : 0
  source = "../../modules/aws-s3"
  
  bucket_name       = "${local.bucket_id}-backup"
  use_random_suffix = false
  environment       = var.environment
  bucket_purpose    = "backup"
  
  # Backup buckets should be more secure
  versioning_enabled = true
  encryption_enabled = true
  public_read_access = false
  force_destroy     = false
  
  # Backup-specific lifecycle rules
  lifecycle_rules = [
    {
      id      = "backup_retention"
      enabled = true
      filter = {
        prefix = ""
        tags   = {}
      }
      transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        },
        {
          days          = 365
          storage_class = "DEEP_ARCHIVE"
        }
      ]
      expiration = {
        days = var.backup_retention_days
      }
    }
  ]
  
  tags = merge(local.common_tags, {
    Name    = "${local.bucket_id}-backup"
    Purpose = "backup"
    Type    = "backup-bucket"
  })
}

# Optional: CloudWatch Log Group for S3 access logging
resource "aws_cloudwatch_log_group" "s3_access_logs" {
  count             = var.access_logging_enabled ? 1 : 0
  name              = "/aws/s3/${local.bucket_id}/access-logs"
  retention_in_days = var.log_retention_days
  
  tags = merge(local.common_tags, {
    Name = "${local.bucket_id}-access-logs"
    Type = "log-group"
  })
}

# Optional: EC2 Instance (if EC2 is enabled)
module "ec2_instance" {
  count  = var.ec2_enabled ? 1 : 0
  source = "../../modules/aws-ec2"
  
  name              = "${local.bucket_id}-server"
  environment       = var.environment
  instance_type     = var.ec2_instance_type
  instance_purpose  = var.ec2_purpose
  
  # Security configuration
  security_group_ids = var.ec2_security_group_ids
  key_name          = var.ec2_key_name
  subnet_id         = var.ec2_subnet_id
  
  # User data script for basic setup
  user_data = var.ec2_enable_s3_integration ? base64encode(templatefile("${path.module}/user_data.tpl", {
    bucket_name = module.main_bucket.bucket.id
    bucket_arn  = module.main_bucket.bucket.arn
    region      = var.environment == "prod" ? "us-east-1" : "us-west-2"
    environment = var.environment
  })) : var.ec2_user_data
  
  # Storage configuration
  root_volume_size = var.ec2_root_volume_size
  root_volume_type = var.ec2_root_volume_type
  
  # Monitoring
  monitoring_enabled        = var.ec2_monitoring_enabled
  enable_cloudwatch_logs    = var.ec2_cloudwatch_logs_enabled
  enable_eip               = var.ec2_enable_elastic_ip
  
  tags = merge(local.common_tags, {
    Component = "compute"
    Service   = "ec2-instance"
    S3Bucket  = module.main_bucket.bucket.id
  })
}

# Optional: IAM Role for EC2 to access S3 (if EC2 and S3 integration enabled)
resource "aws_iam_role" "ec2_s3_role" {
  count = var.ec2_enabled && var.ec2_enable_s3_integration ? 1 : 0
  name  = "${local.bucket_id}-ec2-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM Policy for S3 access
resource "aws_iam_role_policy" "ec2_s3_policy" {
  count = var.ec2_enabled && var.ec2_enable_s3_integration ? 1 : 0
  name  = "${local.bucket_id}-ec2-s3-policy"
  role  = aws_iam_role.ec2_s3_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          module.main_bucket.bucket_arn,
          "${module.main_bucket.bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_s3_profile" {
  count = var.ec2_enabled && var.ec2_enable_s3_integration ? 1 : 0
  name  = "${local.bucket_id}-ec2-s3-profile"
  role  = aws_iam_role.ec2_s3_role[0].name

  tags = local.common_tags
}
