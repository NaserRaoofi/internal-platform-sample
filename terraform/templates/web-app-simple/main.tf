# Web App Simple Template - Complete Web Application Stack
# Cost: $5-15/month (AWS Free Tier optimized)
# Components: S3 (Frontend), EC2 (Backend), RDS (Database), CloudFront (CDN), Security Groups

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
resource "random_id" "app_suffix" {
  byte_length = 4
}

# Local values for consistent naming and tagging
locals {
  app_id = "${var.app_name}-${random_id.app_suffix.hex}"
  
  common_tags = merge(var.tags, {
    Name        = local.app_id
    AppName     = var.app_name
    Environment = var.environment
    Template    = "web-app-simple"
    ManagedBy   = "terraform"
    CostCenter  = "development"
    CreatedBy   = "internal-developer-platform"
    CreatedAt   = timestamp()
  })
}

# Security Groups
module "security_groups" {
  source = "../../modules/aws-security-group"
  
  name              = "${local.app_id}-web"
  environment       = var.environment
  use_random_suffix = false
  description       = "Security group for ${var.app_name} web application"
  
  # Web server access
  ingress_presets = ["ssh", "http", "https"]
  allowed_cidr_blocks = var.allowed_cidr_blocks
  
  # Custom API port if specified
  ingress_rules = var.api_port != 80 && var.api_port != 443 ? [
    {
      from_port   = var.api_port
      to_port     = var.api_port
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
      description = "Custom API port access"
    }
  ] : []
  
  # Create database security group if database is required
  create_database_sg = var.database_required
  database_port      = var.database_type == "postgres" ? 5432 : 3306
  
  tags = merge(local.common_tags, {
    Component = "security"
  })
}

# Frontend Storage (S3)
module "frontend_storage" {
  source = "../../modules/aws-s3"
  
  bucket_name         = "${local.app_id}-frontend"
  use_random_suffix   = false
  environment         = var.environment
  bucket_purpose      = "static-website"
  
  # Website configuration
  website_enabled         = true
  website_index_document  = var.index_document
  website_error_document  = var.error_document
  public_read_access     = true
  
  # CORS for web applications
  cors_rules = [
    {
      allowed_methods = ["GET", "HEAD", "POST", "PUT", "DELETE"]
      allowed_origins = var.cors_allowed_origins
      allowed_headers = ["*"]
      expose_headers  = ["ETag"]
      max_age_seconds = 3000
    }
  ]
  
  # Lifecycle management for cost optimization
  lifecycle_rules = [
    {
      id     = "cleanup_old_versions"
      status = "Enabled"
      noncurrent_version_expiration = {
        noncurrent_days = 30
      }
    }
  ]
  
  tags = merge(local.common_tags, {
    Component = "frontend"
    Service   = "static-hosting"
  })
}

# Backend API Server (if enabled)
module "api_server" {
  count  = var.backend_enabled ? 1 : 0
  source = "../../modules/aws-ec2"
  
  name              = "${local.app_id}-api"
  environment       = var.environment
  instance_type     = var.instance_type
  instance_purpose  = "api-server"
  
  # Security groups
  security_group_ids = [module.security_groups.security_group_id]
  
  # User data script for API setup
  user_data = base64encode(templatefile("${path.module}/scripts/api_setup.sh", {
    app_name     = var.app_name
    environment  = var.environment
    api_port     = var.api_port
    runtime      = var.runtime
    database_required = var.database_required
    database_endpoint = var.database_required ? module.database[0].db_instance_endpoint : ""
    database_name     = var.database_required ? module.database[0].database_name : ""
    database_username = var.database_required ? module.database[0].database_username : ""
    s3_bucket         = module.frontend_storage.bucket_name
  }))
  
  # Instance configuration
  enable_eip                = var.enable_static_ip
  enable_cloudwatch_logs    = var.monitoring_enabled
  monitoring_enabled        = var.monitoring_enabled
  
  # Storage configuration
  root_volume_size = var.root_volume_size
  root_volume_type = "gp3"
  
  tags = merge(local.common_tags, {
    Component = "backend"
    Service   = "api-server"
  })
}

# Database (if required)
module "database" {
  count  = var.database_required ? 1 : 0
  source = "../../modules/aws-rds"
  
  identifier        = "${local.app_id}-db"
  environment       = var.environment
  
  # Database configuration
  engine         = var.database_type
  instance_class = var.database_instance_class
  allocated_storage = var.database_storage_size
  max_allocated_storage = var.database_storage_size * 2
  
  database_name = replace(var.app_name, "-", "_")
  username      = var.database_username
  
  # Security - only allow access from API server and specified security groups
  security_group_ids = [module.security_groups.database_security_group_id]
  allowed_security_groups = var.backend_enabled ? [module.security_groups.security_group_id] : []
  
  # Backup and maintenance
  backup_retention_period = var.backup_enabled ? var.backup_retention_days : 1
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window
  
  # Performance and monitoring
  performance_insights_enabled = var.monitoring_enabled
  monitoring_interval          = var.monitoring_enabled ? 60 : 0
  
  # Security
  storage_encrypted    = true
  deletion_protection  = var.delete_protection
  skip_final_snapshot = !var.delete_protection
  
  tags = merge(local.common_tags, {
    Component = "database"
    Service   = "postgresql"
  })
}

# CDN (CloudFront) for global content delivery
module "cdn" {
  count  = var.cdn_enabled ? 1 : 0
  source = "../../modules/aws-cloudfront"
  
  distribution_name     = "${local.app_id}-cdn"
  environment          = var.environment
  use_random_suffix    = false
  comment              = "CDN for ${var.app_name} web application"
  
  # Origin configuration (S3 website)
  origin_domain_name = module.frontend_storage.website_endpoint
  origin_protocol_policy = "http-only"  # S3 website endpoints only support HTTP
  
  # Cache behavior
  viewer_protocol_policy = "redirect-to-https"
  default_root_object   = var.index_document
  price_class          = var.cdn_price_class
  
  # Enable gzip compression
  compress = true
  
  # Cache policy for web applications
  allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
  cached_methods  = ["GET", "HEAD", "OPTIONS"]
  
  # Forward headers for API requests
  forward_headers = var.backend_enabled ? [
    "Authorization",
    "Content-Type",
    "Accept",
    "Origin",
    "Referer"
  ] : []
  
  # Custom error pages
  custom_error_responses = [
    {
      error_code         = 404
      response_code      = 200
      response_page_path = "/${var.index_document}"
      error_caching_min_ttl = 300
    },
    {
      error_code         = 403
      response_code      = 200
      response_page_path = "/${var.index_document}"
      error_caching_min_ttl = 300
    }
  ]
  
  # SSL certificate (if custom domain provided)
  aliases = var.custom_domain != "" ? [var.custom_domain] : []
  acm_certificate_arn = var.ssl_certificate_arn
  
  # Geo restrictions (if specified)
  geo_restriction_type      = var.geo_restriction_type
  geo_restriction_locations = var.geo_restriction_locations
  
  # Logging (if enabled)
  logging_bucket         = var.access_logs_enabled ? "${module.frontend_storage.bucket_name}.s3.amazonaws.com" : null
  logging_prefix         = var.access_logs_enabled ? "cloudfront-logs/" : ""
  logging_include_cookies = false
  
  tags = merge(local.common_tags, {
    Component = "cdn"
    Service   = "cloudfront"
  })
}

# Load Balancer (if multiple instances needed)
module "load_balancer_sg" {
  count  = var.load_balancer_enabled ? 1 : 0
  source = "../../modules/aws-security-group"
  
  name              = "${local.app_id}-lb"
  environment       = var.environment
  use_random_suffix = false
  description       = "Load balancer security group for ${var.app_name}"
  
  create_load_balancer_sg = true
  application_port       = var.api_port
  load_balancer_cidr_blocks = var.allowed_cidr_blocks
  
  tags = merge(local.common_tags, {
    Component = "load-balancer"
  })
}
