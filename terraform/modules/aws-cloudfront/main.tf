# AWS CloudFront Module - CDN Distribution
# Cost: $0-2/month (AWS Free Tier: 50GB/month, 2M requests)
# Features: HTTPS, Custom domains, Origin failover, Caching

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
resource "random_id" "cloudfront_suffix" {
  count       = var.use_random_suffix ? 1 : 0
  byte_length = 4
}

# Local values for consistent naming and tagging
locals {
  distribution_id = var.use_random_suffix ? "${var.distribution_name}-${random_id.cloudfront_suffix[0].hex}" : var.distribution_name
  
  common_tags = merge(var.tags, {
    Name         = local.distribution_id
    Environment  = var.environment
    ManagedBy    = "terraform"
    CostCenter   = "development"
    Service      = "cloudfront"
    CreatedBy    = "internal-developer-platform"
    CreatedAt    = timestamp()
  })

  # Default origin configuration
  default_origin = {
    domain_name = var.origin_domain_name
    origin_id   = "${local.distribution_id}-origin"
    origin_path = var.origin_path
    
    custom_origin_config = var.origin_protocol_policy != null ? {
      http_port              = var.origin_http_port
      https_port             = var.origin_https_port
      origin_protocol_policy = var.origin_protocol_policy
      origin_ssl_protocols   = var.origin_ssl_protocols
    } : null
    
    s3_origin_config = var.origin_access_control_id != null ? {
      origin_access_identity = ""
    } : null
  }

  # Cache behaviors
  default_cache_behavior = {
    target_origin_id       = local.default_origin.origin_id
    viewer_protocol_policy = var.viewer_protocol_policy
    allowed_methods        = var.allowed_methods
    cached_methods         = var.cached_methods
    compress               = var.compress
    
    forwarded_values = var.cache_policy_id == null ? {
      query_string = var.forward_query_string
      headers      = var.forward_headers
      cookies = {
        forward = var.forward_cookies
      }
    } : null
    
    cache_policy_id = var.cache_policy_id
    origin_request_policy_id = var.origin_request_policy_id
    response_headers_policy_id = var.response_headers_policy_id
    
    min_ttl     = var.min_ttl
    default_ttl = var.default_ttl
    max_ttl     = var.max_ttl
  }

  # Custom error responses
  custom_error_responses = [
    for error in var.custom_error_responses : {
      error_code         = error.error_code
      response_code      = error.response_code
      response_page_path = error.response_page_path
      error_caching_min_ttl = error.error_caching_min_ttl
    }
  ]
}

# Origin Access Control for S3 origins
resource "aws_cloudfront_origin_access_control" "main" {
  count = var.create_origin_access_control ? 1 : 0
  
  name                              = "${local.distribution_id}-oac"
  description                       = "Origin Access Control for ${local.distribution_id}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main" {
  # Origins configuration
  origin {
    domain_name = local.default_origin.domain_name
    origin_id   = local.default_origin.origin_id
    origin_path = local.default_origin.origin_path

    # S3 Origin configuration
    dynamic "s3_origin_config" {
      for_each = var.origin_access_control_id != null || var.create_origin_access_control ? [1] : []
      content {
        origin_access_identity = ""
      }
    }

    # Custom Origin configuration
    dynamic "custom_origin_config" {
      for_each = var.origin_protocol_policy != null ? [1] : []
      content {
        http_port              = var.origin_http_port
        https_port             = var.origin_https_port
        origin_protocol_policy = var.origin_protocol_policy
        origin_ssl_protocols   = var.origin_ssl_protocols
      }
    }

    # Origin Access Control
    origin_access_control_id = var.create_origin_access_control ? aws_cloudfront_origin_access_control.main[0].id : var.origin_access_control_id
  }

  # Additional origins
  dynamic "origin" {
    for_each = var.additional_origins
    content {
      domain_name = origin.value.domain_name
      origin_id   = origin.value.origin_id
      origin_path = lookup(origin.value, "origin_path", "")

      dynamic "s3_origin_config" {
        for_each = lookup(origin.value, "s3_origin_config", null) != null ? [origin.value.s3_origin_config] : []
        content {
          origin_access_identity = s3_origin_config.value.origin_access_identity
        }
      }

      dynamic "custom_origin_config" {
        for_each = lookup(origin.value, "custom_origin_config", null) != null ? [origin.value.custom_origin_config] : []
        content {
          http_port              = custom_origin_config.value.http_port
          https_port             = custom_origin_config.value.https_port
          origin_protocol_policy = custom_origin_config.value.origin_protocol_policy
          origin_ssl_protocols   = custom_origin_config.value.origin_ssl_protocols
        }
      }
    }
  }

  # Default cache behavior
  default_cache_behavior {
    target_origin_id       = local.default_cache_behavior.target_origin_id
    viewer_protocol_policy = local.default_cache_behavior.viewer_protocol_policy
    allowed_methods        = local.default_cache_behavior.allowed_methods
    cached_methods         = local.default_cache_behavior.cached_methods
    compress               = local.default_cache_behavior.compress

    # Legacy forwarded values (for older cache behaviors)
    dynamic "forwarded_values" {
      for_each = local.default_cache_behavior.forwarded_values != null ? [local.default_cache_behavior.forwarded_values] : []
      content {
        query_string = forwarded_values.value.query_string
        headers      = forwarded_values.value.headers
        
        cookies {
          forward = forwarded_values.value.cookies.forward
        }
      }
    }

    # Modern cache policies
    cache_policy_id            = local.default_cache_behavior.cache_policy_id
    origin_request_policy_id   = local.default_cache_behavior.origin_request_policy_id
    response_headers_policy_id = local.default_cache_behavior.response_headers_policy_id

    # TTL settings (only when using forwarded_values)
    min_ttl     = local.default_cache_behavior.forwarded_values != null ? local.default_cache_behavior.min_ttl : null
    default_ttl = local.default_cache_behavior.forwarded_values != null ? local.default_cache_behavior.default_ttl : null
    max_ttl     = local.default_cache_behavior.forwarded_values != null ? local.default_cache_behavior.max_ttl : null

    # Function associations
    dynamic "function_association" {
      for_each = var.function_associations
      content {
        event_type   = function_association.value.event_type
        function_arn = function_association.value.function_arn
      }
    }

    # Lambda@Edge associations
    dynamic "lambda_function_association" {
      for_each = var.lambda_function_associations
      content {
        event_type   = lambda_function_association.value.event_type
        lambda_arn   = lambda_function_association.value.lambda_arn
        include_body = lookup(lambda_function_association.value, "include_body", false)
      }
    }
  }

  # Additional cache behaviors
  dynamic "ordered_cache_behavior" {
    for_each = var.ordered_cache_behaviors
    content {
      path_pattern           = ordered_cache_behavior.value.path_pattern
      target_origin_id       = ordered_cache_behavior.value.target_origin_id
      viewer_protocol_policy = ordered_cache_behavior.value.viewer_protocol_policy
      allowed_methods        = lookup(ordered_cache_behavior.value, "allowed_methods", ["GET", "HEAD"])
      cached_methods         = lookup(ordered_cache_behavior.value, "cached_methods", ["GET", "HEAD"])
      compress               = lookup(ordered_cache_behavior.value, "compress", true)

      cache_policy_id            = lookup(ordered_cache_behavior.value, "cache_policy_id", null)
      origin_request_policy_id   = lookup(ordered_cache_behavior.value, "origin_request_policy_id", null)
      response_headers_policy_id = lookup(ordered_cache_behavior.value, "response_headers_policy_id", null)

      min_ttl     = lookup(ordered_cache_behavior.value, "min_ttl", 0)
      default_ttl = lookup(ordered_cache_behavior.value, "default_ttl", 86400)
      max_ttl     = lookup(ordered_cache_behavior.value, "max_ttl", 31536000)
    }
  }

  # Custom error responses
  dynamic "custom_error_response" {
    for_each = local.custom_error_responses
    content {
      error_code            = custom_error_response.value.error_code
      response_code         = custom_error_response.value.response_code
      response_page_path    = custom_error_response.value.response_page_path
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
    }
  }

  # Distribution configuration
  enabled             = var.enabled
  is_ipv6_enabled     = var.is_ipv6_enabled
  comment             = var.comment
  default_root_object = var.default_root_object
  aliases             = var.aliases
  price_class         = var.price_class
  http_version        = var.http_version
  web_acl_id          = var.web_acl_id

  # Geo restrictions
  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  # SSL/TLS configuration
  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == null && length(var.aliases) == 0
    acm_certificate_arn           = var.acm_certificate_arn
    ssl_support_method            = var.acm_certificate_arn != null ? var.ssl_support_method : null
    minimum_protocol_version      = var.acm_certificate_arn != null ? var.minimum_protocol_version : null
  }

  # Logging configuration
  dynamic "logging_config" {
    for_each = var.logging_bucket != null ? [1] : []
    content {
      include_cookies = var.logging_include_cookies
      bucket          = var.logging_bucket
      prefix          = var.logging_prefix
    }
  }

  tags = local.common_tags

  # Ensure distribution is created after OAC if we're creating one
  depends_on = [aws_cloudfront_origin_access_control.main]
}

# CloudFront Function (for lightweight request/response manipulation)
resource "aws_cloudfront_function" "main" {
  count = var.create_function ? 1 : 0
  
  name    = "${local.distribution_id}-function"
  runtime = "cloudfront-js-1.0"
  comment = "CloudFront function for ${local.distribution_id}"
  publish = true
  code    = var.function_code

  lifecycle {
    create_before_destroy = true
  }
}

# CloudWatch Log Group for real-time logs (if enabled)
resource "aws_cloudwatch_log_group" "realtime_logs" {
  count = var.enable_realtime_logs ? 1 : 0
  
  name              = "/aws/cloudfront/realtime/${local.distribution_id}"
  retention_in_days = var.log_retention_days
  
  tags = local.common_tags
}

# Real-time log configuration
resource "aws_cloudfront_realtime_log_config" "main" {
  count = var.enable_realtime_logs ? 1 : 0
  
  name          = "${local.distribution_id}-realtime-logs"
  fields        = var.realtime_log_fields
  sampling_rate = var.realtime_log_sampling_rate

  endpoint {
    stream_type = "Kinesis"

    kinesis_stream_config {
      role_arn   = aws_iam_role.realtime_logs[0].arn
      stream_arn = aws_kinesis_stream.realtime_logs[0].arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.realtime_logs]
}

# Kinesis stream for real-time logs
resource "aws_kinesis_stream" "realtime_logs" {
  count = var.enable_realtime_logs ? 1 : 0
  
  name             = "${local.distribution_id}-logs"
  shard_count      = 1
  retention_period = 24

  tags = local.common_tags
}

# IAM role for real-time logs
resource "aws_iam_role" "realtime_logs" {
  count = var.enable_realtime_logs ? 1 : 0
  
  name = "${local.distribution_id}-realtime-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM policy for real-time logs
resource "aws_iam_role_policy" "realtime_logs" {
  count = var.enable_realtime_logs ? 1 : 0
  
  name = "${local.distribution_id}-realtime-logs"
  role = aws_iam_role.realtime_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecords",
          "kinesis:PutRecord"
        ]
        Resource = aws_kinesis_stream.realtime_logs[0].arn
      }
    ]
  })
}
