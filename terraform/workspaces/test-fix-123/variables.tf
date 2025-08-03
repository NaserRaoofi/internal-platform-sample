# Variables for Sirwan Test Template

# Basic Configuration
variable "bucket_name" {
  description = "Base name for the S3 bucket (suffix will be added automatically)"
  type        = string
  default     = "sirwan-test-bucket"
  
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be lowercase alphanumeric with hyphens, and cannot start or end with a hyphen."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "bucket_purpose" {
  description = "Purpose of the bucket (e.g., static-website, data-storage, backup)"
  type        = string
  default     = "test-storage"
}

# Security Configuration
variable "versioning_enabled" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "encryption_enabled" {
  description = "Enable server-side encryption"
  type        = bool
  default     = true
}

variable "public_read_access" {
  description = "Allow public read access to bucket objects"
  type        = bool
  default     = false
}

variable "force_destroy" {
  description = "Allow bucket to be destroyed even if it contains objects"
  type        = bool
  default     = false
}

variable "kms_key_id" {
  description = "KMS key ID for encryption (if empty, uses AES256)"
  type        = string
  default     = ""
}

# Website Configuration
variable "website_enabled" {
  description = "Enable static website hosting"
  type        = bool
  default     = false
}

variable "website_index_document" {
  description = "Index document for website hosting"
  type        = string
  default     = "index.html"
}

variable "website_error_document" {
  description = "Error document for website hosting"
  type        = string
  default     = "error.html"
}

variable "website_routing_rules" {
  description = "Website routing rules"
  type = list(object({
    condition = object({
      key_prefix_equals               = optional(string)
      http_error_code_returned_equals = optional(string)
    })
    redirect = object({
      host_name               = optional(string)
      http_redirect_code      = optional(string)
      protocol                = optional(string)
      replace_key_with        = optional(string)
      replace_key_prefix_with = optional(string)
    })
  }))
  default = []
}

# CORS Configuration
variable "cors_enabled" {
  description = "Enable CORS configuration"
  type        = bool
  default     = false
}

variable "cors_allowed_methods" {
  description = "Allowed HTTP methods for CORS"
  type        = list(string)
  default     = ["GET", "POST", "PUT", "DELETE", "HEAD"]
}

variable "cors_allowed_origins" {
  description = "Allowed origins for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "cors_allowed_headers" {
  description = "Allowed headers for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "cors_expose_headers" {
  description = "Headers to expose in CORS"
  type        = list(string)
  default     = ["ETag"]
}

variable "cors_max_age_seconds" {
  description = "Max age for CORS preflight requests"
  type        = number
  default     = 3000
}

# Lifecycle Configuration
variable "lifecycle_enabled" {
  description = "Enable lifecycle management"
  type        = bool
  default     = true
}

variable "lifecycle_prefix" {
  description = "Prefix for lifecycle rules"
  type        = string
  default     = ""
}

variable "lifecycle_tags" {
  description = "Tags for lifecycle rules"
  type        = map(string)
  default     = {}
}

variable "lifecycle_transitions" {
  description = "Lifecycle transition rules"
  type = list(object({
    days          = optional(number)
    date          = optional(string)
    storage_class = string
  }))
  default = [
    {
      days          = 30
      storage_class = "STANDARD_IA"
    },
    {
      days          = 90
      storage_class = "GLACIER"
    }
  ]
}

variable "lifecycle_expiration" {
  description = "Lifecycle expiration rules"
  type = object({
    days                         = optional(number)
    date                         = optional(string)
    expired_object_delete_marker = optional(bool)
  })
  default = null
}

variable "lifecycle_noncurrent_expiration" {
  description = "Non-current version expiration"
  type = object({
    days = number
  })
  default = {
    days = 90
  }
}

variable "lifecycle_noncurrent_transitions" {
  description = "Non-current version transitions"
  type = list(object({
    days          = number
    storage_class = string
  }))
  default = [
    {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  ]
}

# Notification Configuration
variable "notification_enabled" {
  description = "Enable S3 event notifications"
  type        = bool
  default     = false
}

variable "lambda_notifications" {
  description = "Lambda function notifications"
  type = list(object({
    function_arn  = string
    events        = list(string)
    filter_prefix = optional(string)
    filter_suffix = optional(string)
  }))
  default = []
}

variable "sns_notifications" {
  description = "SNS topic notifications"
  type = list(object({
    topic_arn     = string
    events        = list(string)
    filter_prefix = optional(string)
    filter_suffix = optional(string)
  }))
  default = []
}

variable "sqs_notifications" {
  description = "SQS queue notifications"
  type = list(object({
    queue_arn     = string
    events        = list(string)
    filter_prefix = optional(string)
    filter_suffix = optional(string)
  }))
  default = []
}

# Backup Configuration
variable "backup_enabled" {
  description = "Enable backup bucket creation"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Days to retain backup objects"
  type        = number
  default     = 2555  # ~7 years
}

# Logging Configuration
variable "access_logging_enabled" {
  description = "Enable CloudWatch access logging"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

# Tags
variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# EC2 Configuration
variable "ec2_enabled" {
  description = "Enable EC2 instance creation"
  type        = bool
  default     = false
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
  
  validation {
    condition     = contains(["t2.micro", "t3.micro", "t3.small", "t3.medium"], var.ec2_instance_type)
    error_message = "Instance type must be one of: t2.micro, t3.micro, t3.small, t3.medium."
  }
}

variable "ec2_purpose" {
  description = "Purpose of the EC2 instance"
  type        = string
  default     = "s3-processor"
}

variable "ec2_key_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
  default     = ""
}

variable "ec2_security_group_ids" {
  description = "List of security group IDs for EC2 instance"
  type        = list(string)
  default     = []
}

variable "ec2_subnet_id" {
  description = "Subnet ID for EC2 instance placement"
  type        = string
  default     = ""
}

variable "ec2_user_data" {
  description = "Custom user data script for EC2 instance"
  type        = string
  default     = ""
}

variable "ec2_enable_s3_integration" {
  description = "Enable automatic S3 integration (IAM role and user data script)"
  type        = bool
  default     = true
}

variable "ec2_root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 20
  
  validation {
    condition     = var.ec2_root_volume_size >= 8 && var.ec2_root_volume_size <= 100
    error_message = "Root volume size must be between 8 and 100 GB."
  }
}

variable "ec2_root_volume_type" {
  description = "Type of the root volume"
  type        = string
  default     = "gp3"
  
  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.ec2_root_volume_type)
    error_message = "Root volume type must be one of: gp2, gp3, io1, io2."
  }
}

variable "ec2_monitoring_enabled" {
  description = "Enable detailed monitoring for EC2 instance"
  type        = bool
  default     = true
}

variable "ec2_cloudwatch_logs_enabled" {
  description = "Enable CloudWatch logs for EC2 instance"
  type        = bool
  default     = false
}

variable "ec2_enable_elastic_ip" {
  description = "Enable Elastic IP for EC2 instance"
  type        = bool
  default     = false
}
