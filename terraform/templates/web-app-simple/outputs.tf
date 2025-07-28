# Web App Simple Template Outputs

# Application Information
output "application_id" {
  description = "Unique application identifier"
  value       = local.app_id
}

output "application_name" {
  description = "Application name"
  value       = var.app_name
}

output "environment" {
  description = "Environment"
  value       = var.environment
}

# Frontend (S3) Outputs
output "frontend_bucket_name" {
  description = "S3 bucket name for frontend hosting"
  value       = module.frontend_storage.bucket_name
}

output "frontend_bucket_website_endpoint" {
  description = "S3 bucket website endpoint"
  value       = module.frontend_storage.website_endpoint
}

output "frontend_bucket_website_domain" {
  description = "S3 bucket website domain"
  value       = module.frontend_storage.website_domain
}

output "frontend_bucket_arn" {
  description = "S3 bucket ARN"
  value       = module.frontend_storage.bucket_arn
}

# Backend (EC2) Outputs
output "backend_instance_id" {
  description = "Backend EC2 instance ID"
  value       = var.backend_enabled ? module.api_server[0].instance_id : null
}

output "backend_public_ip" {
  description = "Backend server public IP address"
  value       = var.backend_enabled ? module.api_server[0].public_ip : null
}

output "backend_private_ip" {
  description = "Backend server private IP address"
  value       = var.backend_enabled ? module.api_server[0].private_ip : null
}

output "backend_public_dns" {
  description = "Backend server public DNS name"
  value       = var.backend_enabled ? module.api_server[0].public_dns : null
}

output "backend_security_group_id" {
  description = "Backend security group ID"
  value       = module.security_groups.security_group_id
}

# Database Outputs
output "database_endpoint" {
  description = "Database connection endpoint"
  value       = var.database_required ? module.database[0].db_instance_endpoint : null
  sensitive   = true
}

output "database_port" {
  description = "Database port"
  value       = var.database_required ? module.database[0].db_instance_port : null
}

output "database_name" {
  description = "Database name"
  value       = var.database_required ? module.database[0].database_name : null
}

output "database_username" {
  description = "Database username"
  value       = var.database_required ? module.database[0].database_username : null
  sensitive   = true
}

output "database_password" {
  description = "Database password"
  value       = var.database_required ? module.database[0].database_password : null
  sensitive   = true
}

output "database_connection_string" {
  description = "Database connection string"
  value       = var.database_required ? module.database[0].connection_string : null
  sensitive   = true
}

# CDN (CloudFront) Outputs
output "cdn_distribution_id" {
  description = "CloudFront distribution ID"
  value       = var.cdn_enabled ? module.cdn[0].distribution_id : null
}

output "cdn_distribution_domain_name" {
  description = "CloudFront distribution domain name"
  value       = var.cdn_enabled ? module.cdn[0].distribution_domain_name : null
}

output "cdn_distribution_url" {
  description = "CloudFront distribution URL"
  value       = var.cdn_enabled ? module.cdn[0].distribution_url : null
}

output "cdn_distribution_status" {
  description = "CloudFront distribution status"
  value       = var.cdn_enabled ? module.cdn[0].distribution_status : null
}

# Application URLs
output "application_urls" {
  description = "All application access URLs"
  value = {
    # Frontend URLs
    s3_website     = module.frontend_storage.website_endpoint
    cdn_url        = var.cdn_enabled ? module.cdn[0].distribution_url : null
    custom_domain  = var.custom_domain != "" ? "https://${var.custom_domain}" : null
    
    # Backend URLs
    api_endpoint   = var.backend_enabled ? "http://${module.api_server[0].public_ip}:${var.api_port}" : null
    api_public_dns = var.backend_enabled ? "http://${module.api_server[0].public_dns}:${var.api_port}" : null
  }
}

# Security Groups
output "security_group_ids" {
  description = "All security group IDs"
  value = {
    main_sg      = module.security_groups.security_group_id
    database_sg  = var.database_required ? module.security_groups.database_security_group_id : null
    lb_sg        = var.load_balancer_enabled ? module.load_balancer_sg[0].security_group_id : null
  }
}

# Deployment Information
output "deployment_instructions" {
  description = "Instructions for deploying the application"
  value = {
    frontend_deployment = "Upload your static files to S3 bucket: ${module.frontend_storage.bucket_name}"
    backend_deployment  = var.backend_enabled ? "SSH to EC2 instance: ssh ec2-user@${module.api_server[0].public_ip}" : "Backend not enabled"
    database_access     = var.database_required ? "Connect to database at: ${module.database[0].db_instance_endpoint}:${module.database[0].db_instance_port}" : "Database not enabled"
    cdn_invalidation    = var.cdn_enabled ? "Invalidate CloudFront cache after updates: aws cloudfront create-invalidation --distribution-id ${module.cdn[0].distribution_id} --paths '/*'" : "CDN not enabled"
  }
}

# Environment Variables for Backend
output "backend_environment_variables" {
  description = "Environment variables to set on the backend server"
  value = var.backend_enabled ? {
    APP_NAME           = var.app_name
    ENVIRONMENT        = var.environment
    API_PORT           = var.api_port
    S3_BUCKET          = module.frontend_storage.bucket_name
    DATABASE_HOST      = var.database_required ? module.database[0].db_instance_address : ""
    DATABASE_PORT      = var.database_required ? module.database[0].db_instance_port : ""
    DATABASE_NAME      = var.database_required ? module.database[0].database_name : ""
    DATABASE_USER      = var.database_required ? module.database[0].database_username : ""
    CDN_DOMAIN         = var.cdn_enabled ? module.cdn[0].distribution_domain_name : ""
  } : null
  sensitive = true
}

# Cost Estimation
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown (USD)"
  value = {
    s3_storage        = "$0.50 - $2.00 (first 50GB free)"
    ec2_instance      = var.backend_enabled ? "$8.50 (t3.micro, 750 hours free tier)" : "$0.00"
    rds_database      = var.database_required ? "$15.00 (db.t3.micro, 750 hours free tier)" : "$0.00"
    cloudfront_cdn    = var.cdn_enabled ? "$0.50 - $2.00 (50GB transfer, 2M requests free)" : "$0.00"
    data_transfer     = "$0.50 - $2.00"
    total_estimate    = "$10.00 - $25.00 (with free tier), $25.00 - $50.00 (without free tier)"
    free_tier_eligible = "EC2: 750 hours/month, RDS: 750 hours/month, S3: 5GB storage, CloudFront: 50GB transfer"
  }
}

# Configuration Summary
output "configuration_summary" {
  description = "Summary of the deployed configuration"
  value = {
    frontend_enabled    = true
    backend_enabled     = var.backend_enabled
    database_enabled    = var.database_required
    cdn_enabled         = var.cdn_enabled
    monitoring_enabled  = var.monitoring_enabled
    backup_enabled      = var.backup_enabled
    ssl_enabled         = var.ssl_certificate_arn != null
    custom_domain       = var.custom_domain != ""
    geo_restrictions    = var.geo_restriction_type != "none"
    load_balancer       = var.load_balancer_enabled
    
    # Resource counts
    ec2_instances       = var.backend_enabled ? 1 : 0
    rds_instances       = var.database_required ? 1 : 0
    s3_buckets          = 1
    cloudfront_distributions = var.cdn_enabled ? 1 : 0
    security_groups     = 1 + (var.database_required ? 1 : 0) + (var.load_balancer_enabled ? 1 : 0)
  }
}

# Tags Applied
output "tags" {
  description = "Tags applied to all resources"
  value       = local.common_tags
}
