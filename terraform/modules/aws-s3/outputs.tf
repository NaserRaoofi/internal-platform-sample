# AWS S3 Module Outputs

output "bucket" {
  description = "Complete S3 bucket information"
  value = {
    id                          = aws_s3_bucket.main.id
    arn                         = aws_s3_bucket.main.arn
    bucket_domain_name          = aws_s3_bucket.main.bucket_domain_name
    bucket_regional_domain_name = aws_s3_bucket.main.bucket_regional_domain_name
    hosted_zone_id              = aws_s3_bucket.main.hosted_zone_id
    region                      = aws_s3_bucket.main.region
  }
}

output "website" {
  description = "Static website hosting information"
  value = var.website_enabled ? {
    endpoint = aws_s3_bucket_website_configuration.main[0].website_endpoint
    domain   = aws_s3_bucket_website_configuration.main[0].website_domain
    url      = "http://${aws_s3_bucket_website_configuration.main[0].website_endpoint}"
  } : null
}

output "security" {
  description = "Security configuration"
  value = {
    public_access_blocked = !var.public_read_access
    encryption_enabled    = var.encryption_enabled
    kms_key_id           = var.kms_key_id
    versioning_enabled   = var.versioning_enabled
  }
}

output "configuration" {
  description = "Bucket configuration details"
  value = {
    versioning_enabled    = var.versioning_enabled
    encryption_enabled    = var.encryption_enabled
    website_enabled       = var.website_enabled
    notification_enabled  = var.notification_enabled
    cors_enabled         = length(var.cors_rules) > 0
    lifecycle_enabled    = length(var.lifecycle_rules) > 0
  }
}

output "endpoints" {
  description = "Various S3 endpoints"
  value = {
    s3_uri                = "s3://${aws_s3_bucket.main.id}"
    https_url            = "https://${aws_s3_bucket.main.bucket_domain_name}"
    regional_url         = "https://${aws_s3_bucket.main.bucket_regional_domain_name}"
    website_url          = var.website_enabled ? "http://${aws_s3_bucket_website_configuration.main[0].website_endpoint}" : null
    console_url          = "https://s3.console.aws.amazon.com/s3/buckets/${aws_s3_bucket.main.id}"
  }
}

output "usage_examples" {
  description = "Common usage examples"
  value = {
    aws_cli_sync    = "aws s3 sync ./local-folder s3://${aws_s3_bucket.main.id}/"
    aws_cli_upload  = "aws s3 cp ./file.txt s3://${aws_s3_bucket.main.id}/"
    aws_cli_download = "aws s3 cp s3://${aws_s3_bucket.main.id}/file.txt ./file.txt"
    terraform_data  = "data \"aws_s3_bucket\" \"${replace(aws_s3_bucket.main.id, "-", "_")}\" { bucket = \"${aws_s3_bucket.main.id}\" }"
  }
}

output "cost_estimate" {
  description = "Estimated monthly costs (USD)"
  value = {
    storage_standard = "~$0.023 per GB/month (first 50 TB)"
    requests_put     = "~$0.0005 per 1,000 PUT requests"
    requests_get     = "~$0.0004 per 1,000 GET requests"
    data_transfer    = "~$0.09 per GB (after 1 GB free)"
    note            = "Costs depend on usage patterns and data transfer"
  }
}

output "tags" {
  description = "Applied tags"
  value = aws_s3_bucket.main.tags
}

# Raw outputs for backward compatibility
output "bucket_id" {
  description = "S3 bucket ID (name)"
  value       = aws_s3_bucket.main.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.main.arn
}

output "bucket_domain_name" {
  description = "S3 bucket domain name"
  value       = aws_s3_bucket.main.bucket_domain_name
}

output "website_endpoint" {
  description = "S3 website endpoint (if website hosting is enabled)"
  value       = var.website_enabled ? aws_s3_bucket_website_configuration.main[0].website_endpoint : null
}
