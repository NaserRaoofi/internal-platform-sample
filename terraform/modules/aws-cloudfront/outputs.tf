# AWS CloudFront Module Outputs

# Distribution Information
output "distribution_id" {
  description = "The CloudFront distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "distribution_arn" {
  description = "The CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.main.arn
}

output "distribution_domain_name" {
  description = "The CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "distribution_hosted_zone_id" {
  description = "The CloudFront distribution hosted zone ID"
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}

output "distribution_status" {
  description = "The CloudFront distribution status"
  value       = aws_cloudfront_distribution.main.status
}

output "distribution_etag" {
  description = "The CloudFront distribution ETag"
  value       = aws_cloudfront_distribution.main.etag
}

# URLs
output "distribution_url" {
  description = "The CloudFront distribution URL (HTTPS)"
  value       = "https://${aws_cloudfront_distribution.main.domain_name}"
}

output "distribution_aliases" {
  description = "The CloudFront distribution aliases"
  value       = aws_cloudfront_distribution.main.aliases
}

# Origin Access Control
output "origin_access_control_id" {
  description = "The Origin Access Control ID (if created)"
  value       = var.create_origin_access_control ? aws_cloudfront_origin_access_control.main[0].id : null
}

output "origin_access_control_etag" {
  description = "The Origin Access Control ETag (if created)"
  value       = var.create_origin_access_control ? aws_cloudfront_origin_access_control.main[0].etag : null
}

# CloudFront Function
output "function_arn" {
  description = "The CloudFront function ARN (if created)"
  value       = var.create_function ? aws_cloudfront_function.main[0].arn : null
}

output "function_etag" {
  description = "The CloudFront function ETag (if created)"
  value       = var.create_function ? aws_cloudfront_function.main[0].etag : null
}

# Real-time Logs
output "realtime_log_config_arn" {
  description = "The real-time log configuration ARN (if enabled)"
  value       = var.enable_realtime_logs ? aws_cloudfront_realtime_log_config.main[0].arn : null
}

output "kinesis_stream_arn" {
  description = "The Kinesis stream ARN for real-time logs (if enabled)"
  value       = var.enable_realtime_logs ? aws_kinesis_stream.realtime_logs[0].arn : null
}

output "cloudwatch_log_group_name" {
  description = "The CloudWatch log group name for real-time logs (if enabled)"
  value       = var.enable_realtime_logs ? aws_cloudwatch_log_group.realtime_logs[0].name : null
}

# Configuration Details
output "price_class" {
  description = "The CloudFront distribution price class"
  value       = aws_cloudfront_distribution.main.price_class
}

output "enabled" {
  description = "Whether the CloudFront distribution is enabled"
  value       = aws_cloudfront_distribution.main.enabled
}

output "is_ipv6_enabled" {
  description = "Whether IPv6 is enabled for the distribution"
  value       = aws_cloudfront_distribution.main.is_ipv6_enabled
}

output "http_version" {
  description = "The HTTP version supported by the distribution"
  value       = aws_cloudfront_distribution.main.http_version
}

# Security
output "viewer_certificate" {
  description = "The viewer certificate configuration"
  value = {
    acm_certificate_arn            = aws_cloudfront_distribution.main.viewer_certificate[0].acm_certificate_arn
    cloudfront_default_certificate = aws_cloudfront_distribution.main.viewer_certificate[0].cloudfront_default_certificate
    ssl_support_method             = aws_cloudfront_distribution.main.viewer_certificate[0].ssl_support_method
    minimum_protocol_version       = aws_cloudfront_distribution.main.viewer_certificate[0].minimum_protocol_version
  }
}

output "web_acl_id" {
  description = "The AWS WAF web ACL ID associated with the distribution"
  value       = aws_cloudfront_distribution.main.web_acl_id
}

# Origins Information
output "origins" {
  description = "The origins configured for the distribution"
  value = [
    for origin in aws_cloudfront_distribution.main.origin : {
      domain_name = origin.domain_name
      origin_id   = origin.origin_id
      origin_path = origin.origin_path
    }
  ]
}

# Cache Behaviors
output "default_cache_behavior" {
  description = "The default cache behavior configuration"
  value = {
    target_origin_id       = aws_cloudfront_distribution.main.default_cache_behavior[0].target_origin_id
    viewer_protocol_policy = aws_cloudfront_distribution.main.default_cache_behavior[0].viewer_protocol_policy
    allowed_methods        = aws_cloudfront_distribution.main.default_cache_behavior[0].allowed_methods
    cached_methods         = aws_cloudfront_distribution.main.default_cache_behavior[0].cached_methods
    compress               = aws_cloudfront_distribution.main.default_cache_behavior[0].compress
  }
}

# Geo Restrictions
output "geo_restriction" {
  description = "The geo restriction configuration"
  value = {
    restriction_type = aws_cloudfront_distribution.main.restrictions[0].geo_restriction[0].restriction_type
    locations        = aws_cloudfront_distribution.main.restrictions[0].geo_restriction[0].locations
  }
}

# Logging
output "logging_config" {
  description = "The logging configuration (if enabled)"
  value = length(aws_cloudfront_distribution.main.logging_config) > 0 ? {
    bucket          = aws_cloudfront_distribution.main.logging_config[0].bucket
    prefix          = aws_cloudfront_distribution.main.logging_config[0].prefix
    include_cookies = aws_cloudfront_distribution.main.logging_config[0].include_cookies
  } : null
}

# Monitoring Integration
output "cloudwatch_metrics_enabled" {
  description = "Whether CloudWatch metrics are available for the distribution"
  value       = true
}

# Cost Optimization Information
output "cost_optimization_tags" {
  description = "Tags applied for cost optimization and tracking"
  value       = aws_cloudfront_distribution.main.tags_all
}

# Cache Performance Metrics
output "cache_policy_info" {
  description = "Information about cache policies used"
  value = {
    default_cache_policy_id            = aws_cloudfront_distribution.main.default_cache_behavior[0].cache_policy_id
    default_origin_request_policy_id   = aws_cloudfront_distribution.main.default_cache_behavior[0].origin_request_policy_id
    default_response_headers_policy_id = aws_cloudfront_distribution.main.default_cache_behavior[0].response_headers_policy_id
  }
}

# Last Modified
output "last_modified_time" {
  description = "The last modified time of the distribution"
  value       = aws_cloudfront_distribution.main.last_modified_time
}
