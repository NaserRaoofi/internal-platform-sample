# AWS CloudFront Module Variables

variable "distribution_name" {
  description = "Name for the CloudFront distribution"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{0,62}$", var.distribution_name))
    error_message = "Distribution name must start with a letter, be 1-63 characters long, and contain only alphanumeric characters and hyphens."
  }
}

variable "use_random_suffix" {
  description = "Add random suffix to distribution name to ensure uniqueness"
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

# Origin Configuration
variable "origin_domain_name" {
  description = "Domain name of the origin (S3 bucket or custom origin)"
  type        = string
}

variable "origin_path" {
  description = "Path to append to origin requests"
  type        = string
  default     = ""
}

variable "origin_protocol_policy" {
  description = "Origin protocol policy for custom origins (http-only, https-only, match-viewer)"
  type        = string
  default     = null
  
  validation {
    condition = var.origin_protocol_policy == null || contains(["http-only", "https-only", "match-viewer"], var.origin_protocol_policy)
    error_message = "Origin protocol policy must be one of: http-only, https-only, match-viewer."
  }
}

variable "origin_http_port" {
  description = "HTTP port for custom origin"
  type        = number
  default     = 80
}

variable "origin_https_port" {
  description = "HTTPS port for custom origin"
  type        = number
  default     = 443
}

variable "origin_ssl_protocols" {
  description = "SSL/TLS protocols for custom origin"
  type        = list(string)
  default     = ["TLSv1.2"]
}

variable "origin_access_control_id" {
  description = "ID of existing Origin Access Control (for S3 origins)"
  type        = string
  default     = null
}

variable "create_origin_access_control" {
  description = "Create a new Origin Access Control for S3 origins"
  type        = bool
  default     = false
}

variable "additional_origins" {
  description = "List of additional origins for the distribution"
  type = list(object({
    domain_name = string
    origin_id   = string
    origin_path = optional(string, "")
    s3_origin_config = optional(object({
      origin_access_identity = string
    }))
    custom_origin_config = optional(object({
      http_port              = number
      https_port             = number
      origin_protocol_policy = string
      origin_ssl_protocols   = list(string)
    }))
  }))
  default = []
}

# Cache Behavior Configuration
variable "viewer_protocol_policy" {
  description = "Viewer protocol policy (allow-all, https-only, redirect-to-https)"
  type        = string
  default     = "redirect-to-https"
  
  validation {
    condition     = contains(["allow-all", "https-only", "redirect-to-https"], var.viewer_protocol_policy)
    error_message = "Viewer protocol policy must be one of: allow-all, https-only, redirect-to-https."
  }
}

variable "allowed_methods" {
  description = "HTTP methods allowed by CloudFront"
  type        = list(string)
  default     = ["GET", "HEAD", "OPTIONS"]
}

variable "cached_methods" {
  description = "HTTP methods that CloudFront caches responses for"
  type        = list(string)
  default     = ["GET", "HEAD"]
}

variable "compress" {
  description = "Enable CloudFront compression"
  type        = bool
  default     = true
}

# Cache Policy Configuration (Modern approach)
variable "cache_policy_id" {
  description = "ID of cache policy to use (overrides forwarded_values)"
  type        = string
  default     = null
}

variable "origin_request_policy_id" {
  description = "ID of origin request policy to use"
  type        = string
  default     = null
}

variable "response_headers_policy_id" {
  description = "ID of response headers policy to use"
  type        = string
  default     = null
}

# Legacy Cache Configuration (when not using cache policies)
variable "forward_query_string" {
  description = "Forward query strings to origin (legacy)"
  type        = bool
  default     = false
}

variable "forward_headers" {
  description = "Headers to forward to origin (legacy)"
  type        = list(string)
  default     = []
}

variable "forward_cookies" {
  description = "Cookie forwarding behavior (none, whitelist, all) (legacy)"
  type        = string
  default     = "none"
  
  validation {
    condition     = contains(["none", "whitelist", "all"], var.forward_cookies)
    error_message = "Forward cookies must be one of: none, whitelist, all."
  }
}

variable "min_ttl" {
  description = "Minimum TTL for cached objects (seconds)"
  type        = number
  default     = 0
}

variable "default_ttl" {
  description = "Default TTL for cached objects (seconds)"
  type        = number
  default     = 86400
}

variable "max_ttl" {
  description = "Maximum TTL for cached objects (seconds)"
  type        = number
  default     = 31536000
}

# Additional Cache Behaviors
variable "ordered_cache_behaviors" {
  description = "List of ordered cache behaviors"
  type = list(object({
    path_pattern           = string
    target_origin_id       = string
    viewer_protocol_policy = string
    allowed_methods        = optional(list(string), ["GET", "HEAD"])
    cached_methods         = optional(list(string), ["GET", "HEAD"])
    compress               = optional(bool, true)
    cache_policy_id        = optional(string)
    origin_request_policy_id = optional(string)
    response_headers_policy_id = optional(string)
    min_ttl                = optional(number, 0)
    default_ttl            = optional(number, 86400)
    max_ttl                = optional(number, 31536000)
  }))
  default = []
}

# Error Pages
variable "custom_error_responses" {
  description = "List of custom error responses"
  type = list(object({
    error_code            = number
    response_code         = optional(number)
    response_page_path    = optional(string)
    error_caching_min_ttl = optional(number, 300)
  }))
  default = []
}

# Distribution Configuration
variable "enabled" {
  description = "Enable the CloudFront distribution"
  type        = bool
  default     = true
}

variable "is_ipv6_enabled" {
  description = "Enable IPv6 support"
  type        = bool
  default     = true
}

variable "comment" {
  description = "Comment for the distribution"
  type        = string
  default     = ""
}

variable "default_root_object" {
  description = "Default root object (e.g., index.html)"
  type        = string
  default     = ""
}

variable "aliases" {
  description = "List of alternate domain names (CNAMEs)"
  type        = list(string)
  default     = []
}

variable "price_class" {
  description = "Price class for the distribution (PriceClass_All, PriceClass_200, PriceClass_100)"
  type        = string
  default     = "PriceClass_100"
  
  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.price_class)
    error_message = "Price class must be one of: PriceClass_All, PriceClass_200, PriceClass_100."
  }
}

variable "http_version" {
  description = "HTTP version to use (http1.1, http2)"
  type        = string
  default     = "http2"
  
  validation {
    condition     = contains(["http1.1", "http2"], var.http_version)
    error_message = "HTTP version must be one of: http1.1, http2."
  }
}

variable "web_acl_id" {
  description = "AWS WAF web ACL ID to associate with the distribution"
  type        = string
  default     = null
}

# SSL/TLS Configuration
variable "acm_certificate_arn" {
  description = "ARN of ACM certificate for HTTPS (must be in us-east-1)"
  type        = string
  default     = null
}

variable "ssl_support_method" {
  description = "SSL support method (sni-only, vip)"
  type        = string
  default     = "sni-only"
  
  validation {
    condition     = contains(["sni-only", "vip"], var.ssl_support_method)
    error_message = "SSL support method must be one of: sni-only, vip."
  }
}

variable "minimum_protocol_version" {
  description = "Minimum SSL/TLS protocol version"
  type        = string
  default     = "TLSv1.2_2021"
}

# Geo Restrictions
variable "geo_restriction_type" {
  description = "Type of geo restriction (none, whitelist, blacklist)"
  type        = string
  default     = "none"
  
  validation {
    condition     = contains(["none", "whitelist", "blacklist"], var.geo_restriction_type)
    error_message = "Geo restriction type must be one of: none, whitelist, blacklist."
  }
}

variable "geo_restriction_locations" {
  description = "List of country codes for geo restrictions"
  type        = list(string)
  default     = []
}

# Logging Configuration
variable "logging_bucket" {
  description = "S3 bucket for access logs (must end with .s3.amazonaws.com)"
  type        = string
  default     = null
}

variable "logging_include_cookies" {
  description = "Include cookies in access logs"
  type        = bool
  default     = false
}

variable "logging_prefix" {
  description = "Prefix for access log files"
  type        = string
  default     = ""
}

# Real-time Logs
variable "enable_realtime_logs" {
  description = "Enable real-time logs"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
  
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

variable "realtime_log_fields" {
  description = "Fields to include in real-time logs"
  type        = list(string)
  default = [
    "timestamp",
    "c-ip",
    "cs-method",
    "cs-uri-stem",
    "sc-status",
    "cs-bytes",
    "time-taken"
  ]
}

variable "realtime_log_sampling_rate" {
  description = "Sampling rate for real-time logs (1-100)"
  type        = number
  default     = 100
  
  validation {
    condition     = var.realtime_log_sampling_rate >= 1 && var.realtime_log_sampling_rate <= 100
    error_message = "Sampling rate must be between 1 and 100."
  }
}

# Function Configuration
variable "create_function" {
  description = "Create a CloudFront function"
  type        = bool
  default     = false
}

variable "function_code" {
  description = "JavaScript code for CloudFront function"
  type        = string
  default     = "function handler(event) { return event.request; }"
}

variable "function_associations" {
  description = "List of CloudFront function associations"
  type = list(object({
    event_type   = string
    function_arn = string
  }))
  default = []
}

variable "lambda_function_associations" {
  description = "List of Lambda@Edge function associations"
  type = list(object({
    event_type   = string
    lambda_arn   = string
    include_body = optional(bool, false)
  }))
  default = []
}

# Tags
variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
