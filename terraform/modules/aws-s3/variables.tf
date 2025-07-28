# AWS S3 Module Variables

variable "bucket_name" {
  description = "Name of the S3 bucket (must be globally unique)"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9\\-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be 3-63 characters, start and end with lowercase letter or number, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "use_random_suffix" {
  description = "Add random suffix to bucket name to ensure uniqueness"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "bucket_purpose" {
  description = "Purpose of the bucket (static-website, data-storage, backup, logs, etc.)"
  type        = string
  default     = "general"
}

variable "force_destroy" {
  description = "Allow bucket to be destroyed even if it contains objects"
  type        = bool
  default     = false
}

variable "versioning_enabled" {
  description = "Enable versioning for the bucket"
  type        = bool
  default     = false
}

variable "encryption_enabled" {
  description = "Enable server-side encryption"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption (leave empty for S3 managed encryption)"
  type        = string
  default     = ""
}

variable "public_read_access" {
  description = "Allow public read access to bucket objects"
  type        = bool
  default     = false
}

variable "website_enabled" {
  description = "Enable static website hosting"
  type        = bool
  default     = false
}

variable "website_index_document" {
  description = "Index document for static website"
  type        = string
  default     = "index.html"
}

variable "website_error_document" {
  description = "Error document for static website"
  type        = string
  default     = "error.html"
}

variable "website_routing_rules" {
  description = "Routing rules for static website"
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

variable "cors_rules" {
  description = "CORS configuration rules"
  type = list(object({
    allowed_headers = optional(list(string))
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string))
    max_age_seconds = optional(number)
  }))
  default = []
}

variable "lifecycle_rules" {
  description = "Lifecycle configuration rules"
  type = list(object({
    id      = string
    enabled = bool
    filter = optional(object({
      prefix = optional(string)
      tags   = optional(map(string))
    }))
    expiration = optional(object({
      days                         = optional(number)
      date                         = optional(string)
      expired_object_delete_marker = optional(bool)
    }))
    transitions = optional(list(object({
      days          = optional(number)
      date          = optional(string)
      storage_class = string
    })))
    noncurrent_version_expiration = optional(object({
      days = number
    }))
    noncurrent_version_transitions = optional(list(object({
      days          = number
      storage_class = string
    })))
  }))
  default = []
}

variable "notification_enabled" {
  description = "Enable bucket notifications"
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

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
