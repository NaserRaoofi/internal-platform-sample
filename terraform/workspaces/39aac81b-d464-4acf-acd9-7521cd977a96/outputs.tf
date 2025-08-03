# Outputs for Sirwan Test Template

# Main Bucket Information
output "bucket_info" {
  description = "Main S3 bucket information"
  value = {
    bucket_name         = module.main_bucket.bucket.id
    bucket_arn          = module.main_bucket.bucket.arn
    bucket_id           = module.main_bucket.bucket.id
    bucket_domain_name  = module.main_bucket.bucket.bucket_domain_name
    region             = module.main_bucket.bucket.region
  }
}

# Security Configuration
output "security" {
  description = "Security configuration details"
  value = {
    versioning_enabled = var.versioning_enabled
    encryption_enabled = var.encryption_enabled
    public_read_access = var.public_read_access
    kms_key_id        = var.kms_key_id != "" ? var.kms_key_id : "AES256"
  }
}

# Website Configuration (if enabled)
output "website" {
  description = "Website configuration details"
  value = var.website_enabled ? {
    enabled          = true
    website_endpoint = module.main_bucket.website_endpoint
    website_url      = "http://${module.main_bucket.website_endpoint}"
    index_document   = var.website_index_document
    error_document   = var.website_error_document
  } : {
    enabled = false
    message = "Website hosting not enabled for this bucket"
  }
}

# Access URLs and Endpoints
output "endpoints" {
  description = "Various access endpoints for the bucket"
  value = module.main_bucket.endpoints
}

# Usage Examples
output "usage_examples" {
  description = "Common usage examples for this bucket"
  value = module.main_bucket.usage_examples
}

# Backup Bucket (if enabled)
output "backup_bucket" {
  description = "Backup bucket information"
  value = var.backup_enabled ? {
    enabled             = true
    backup_bucket_name  = module.backup_bucket[0].bucket.id
    backup_bucket_arn   = module.backup_bucket[0].bucket.arn
    retention_days      = var.backup_retention_days
  } : {
    enabled = false
    message = "Backup bucket not enabled"
  }
}

# CloudWatch Logs (if enabled)
output "logging" {
  description = "Logging configuration"
  value = var.access_logging_enabled ? {
    enabled           = true
    log_group_name    = aws_cloudwatch_log_group.s3_access_logs[0].name
    log_group_arn     = aws_cloudwatch_log_group.s3_access_logs[0].arn
    retention_days    = var.log_retention_days
  } : {
    enabled = false
    message = "Access logging not enabled"
  }
}

# Configuration Summary
output "configuration" {
  description = "Complete configuration summary"
  value = {
    bucket_purpose        = var.bucket_purpose
    environment          = var.environment
    website_enabled      = var.website_enabled
    cors_enabled         = var.cors_enabled
    lifecycle_enabled    = var.lifecycle_enabled
    notification_enabled = var.notification_enabled
    backup_enabled       = var.backup_enabled
    logging_enabled      = var.access_logging_enabled
  }
}

# Cost Estimation
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown (USD)"
  value = {
    storage_standard = "$0.023 per GB/month (first 50 TB)"
    requests_put     = "$0.0005 per 1,000 PUT requests"
    requests_get     = "$0.0004 per 1,000 GET requests"
    data_transfer    = "$0.09 per GB (after 1 GB free)"
    lifecycle_transitions = var.lifecycle_enabled ? "$0.01 per 1,000 transitions" : "$0.00"
    backup_storage   = var.backup_enabled ? "$0.004-0.0125 per GB (depending on storage class)" : "$0.00"
    cloudwatch_logs  = var.access_logging_enabled ? "$0.50 per GB ingested" : "$0.00"
    ec2_instance     = var.ec2_enabled ? (var.ec2_instance_type == "t2.micro" ? "$0.00 (free tier)" : (var.ec2_instance_type == "t3.micro" ? "$7.59" : "$15.18")) : "$0.00"
    ec2_storage      = var.ec2_enabled ? "$2.00 (${var.ec2_root_volume_size}GB EBS)" : "$0.00"
    ec2_elastic_ip   = var.ec2_enabled && var.ec2_enable_elastic_ip ? "$3.65" : "$0.00"
    total_estimate   = var.ec2_enabled ? "$1.00 - $25.00 (depending on usage patterns and instance type)" : "$0.50 - $5.00 (S3 only)"
    note            = "Costs depend heavily on storage amount, request patterns, data transfer, and EC2 usage"
  }
}

# Tags Applied
output "tags" {
  description = "Tags applied to all resources"
  value = module.main_bucket.tags
}

# Quick Start Guide
output "quick_start_guide" {
  description = "Quick start guide for using your S3 bucket and EC2 instance"
  value = {
    bucket_name = module.main_bucket.bucket.id
    steps = concat([
      "1. Your S3 bucket '${module.main_bucket.bucket.id}' is now ready",
      "2. Upload files: aws s3 cp ./file.txt s3://${module.main_bucket.bucket.id}/",
      "3. List contents: aws s3 ls s3://${module.main_bucket.bucket.id}/",
      "4. Download files: aws s3 cp s3://${module.main_bucket.bucket.id}/file.txt ./downloaded-file.txt",
      var.website_enabled ? "5. Website URL: http://${module.main_bucket.website.endpoint}" : "5. Website hosting disabled",
      var.backup_enabled ? "6. Backup bucket: ${module.backup_bucket[0].bucket.id}" : "6. No backup bucket configured",
      "7. Console access: https://s3.console.aws.amazon.com/s3/buckets/${module.main_bucket.bucket.id}"
    ], var.ec2_enabled ? [
      "",
      "🖥️  EC2 Instance Commands:",
      "8. SSH to instance: ${var.ec2_key_name != "" ? "ssh -i ~/.ssh/${var.ec2_key_name}.pem ec2-user@${module.ec2_instance[0].public_ip}" : "Configure SSH key first"}",
      var.ec2_enable_s3_integration ? "9. S3 sync commands available on instance: s3-sync {list|download|upload|info}" : "9. Manual S3 integration required",
      "10. Instance monitoring: https://console.aws.amazon.com/ec2/v2/home?region=${var.environment == "prod" ? "us-east-1" : "us-west-2"}#InstanceDetails:instanceId=${module.ec2_instance[0].instance_id}"
    ] : [])
  }
}

# Resource IDs for Integration
output "resource_ids" {
  description = "Resource IDs for integration with other services"
  value = {
    main_bucket_name    = module.main_bucket.bucket.id
    main_bucket_arn     = module.main_bucket.bucket.arn
    backup_bucket_name  = var.backup_enabled ? module.backup_bucket[0].bucket.id : null
    backup_bucket_arn   = var.backup_enabled ? module.backup_bucket[0].bucket_arn : null
    log_group_name      = var.access_logging_enabled ? aws_cloudwatch_log_group.s3_access_logs[0].name : null
    ec2_instance_id     = var.ec2_enabled ? module.ec2_instance[0].instance_id : null
    ec2_public_ip       = var.ec2_enabled ? module.ec2_instance[0].public_ip : null
    ec2_private_ip      = var.ec2_enabled ? module.ec2_instance[0].private_ip : null
  }
}

# EC2 Instance Information (if enabled)
output "ec2_instance" {
  description = "EC2 instance information"
  value = var.ec2_enabled ? {
    enabled           = true
    instance_id       = module.ec2_instance[0].instance_id
    instance_type     = var.ec2_instance_type
    public_ip         = module.ec2_instance[0].public_ip
    private_ip        = module.ec2_instance[0].private_ip
    public_dns        = module.ec2_instance[0].public_dns
    availability_zone = module.ec2_instance[0].availability_zone
    s3_integration    = var.ec2_enable_s3_integration
    ssh_command       = var.ec2_key_name != "" ? "ssh -i ~/.ssh/${var.ec2_key_name}.pem ec2-user@${module.ec2_instance[0].public_ip}" : "SSH key not configured"
    s3_commands = {
      list_bucket     = "s3-sync list"
      download_files  = "s3-sync download"
      upload_files    = "s3-sync upload"
      show_info       = "s3-sync info"
    }
  } : {
    enabled = false
    message = "EC2 instance not enabled for this deployment"
  }
}
