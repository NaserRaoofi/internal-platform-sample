# Web App Simple Template Variables

variable "app_name" {
  description = "Name of the web application"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{0,62}$", var.app_name))
    error_message = "App name must start with a letter, be 1-63 characters long, and contain only alphanumeric characters and hyphens."
  }
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

# Network Configuration
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the application"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Frontend Configuration
variable "index_document" {
  description = "Index document for the website"
  type        = string
  default     = "index.html"
}

variable "error_document" {
  description = "Error document for the website"
  type        = string
  default     = "error.html"
}

variable "cors_allowed_origins" {
  description = "CORS allowed origins for the frontend"
  type        = list(string)
  default     = ["*"]
}

# Backend Configuration
variable "backend_enabled" {
  description = "Enable backend API server"
  type        = bool
  default     = true
}

variable "instance_type" {
  description = "EC2 instance type for backend server"
  type        = string
  default     = "t3.micro"
  
  validation {
    condition     = can(regex("^[a-z0-9]+\\.[a-z0-9]+$", var.instance_type))
    error_message = "Instance type must be a valid EC2 instance type (e.g., t3.micro)."
  }
}

variable "api_port" {
  description = "Port for the API server"
  type        = number
  default     = 8080
  
  validation {
    condition     = var.api_port >= 1 && var.api_port <= 65535
    error_message = "API port must be between 1 and 65535."
  }
}

variable "runtime" {
  description = "Runtime for the API server (nodejs, python, java, go)"
  type        = string
  default     = "nodejs"
  
  validation {
    condition     = contains(["nodejs", "python", "java", "go"], var.runtime)
    error_message = "Runtime must be one of: nodejs, python, java, go."
  }
}

variable "enable_static_ip" {
  description = "Enable Elastic IP for the backend server"
  type        = bool
  default     = false
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 20
  
  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 1000
    error_message = "Root volume size must be between 8 and 1000 GB."
  }
}

# Database Configuration
variable "database_required" {
  description = "Enable database for the application"
  type        = bool
  default     = false
}

variable "database_type" {
  description = "Database engine type"
  type        = string
  default     = "postgres"
  
  validation {
    condition     = contains(["postgres", "mysql"], var.database_type)
    error_message = "Database type must be one of: postgres, mysql."
  }
}

variable "database_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
  
  validation {
    condition     = can(regex("^db\\.[a-z0-9]+\\.[a-z0-9]+$", var.database_instance_class))
    error_message = "Database instance class must be a valid RDS instance type (e.g., db.t3.micro)."
  }
}

variable "database_storage_size" {
  description = "Initial database storage size in GB"
  type        = number
  default     = 20
  
  validation {
    condition     = var.database_storage_size >= 20 && var.database_storage_size <= 1000
    error_message = "Database storage size must be between 20 and 1000 GB."
  }
}

variable "database_username" {
  description = "Database master username"
  type        = string
  default     = "appuser"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", var.database_username))
    error_message = "Database username must start with a letter and contain only alphanumeric characters and underscores."
  }
}

# Backup Configuration
variable "backup_enabled" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
  
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "Backup retention days must be between 1 and 35."
  }
}

variable "backup_window" {
  description = "Preferred backup window (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window (UTC)"
  type        = string
  default     = "Sun:04:00-Sun:05:00"
}

# CDN Configuration
variable "cdn_enabled" {
  description = "Enable CloudFront CDN"
  type        = bool
  default     = true
}

variable "cdn_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
  
  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.cdn_price_class)
    error_message = "CDN price class must be one of: PriceClass_All, PriceClass_200, PriceClass_100."
  }
}

variable "custom_domain" {
  description = "Custom domain name for the application"
  type        = string
  default     = ""
}

variable "ssl_certificate_arn" {
  description = "ARN of ACM SSL certificate (must be in us-east-1 for CloudFront)"
  type        = string
  default     = null
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

# Load Balancer Configuration
variable "load_balancer_enabled" {
  description = "Enable load balancer for high availability"
  type        = bool
  default     = false
}

# Monitoring Configuration
variable "monitoring_enabled" {
  description = "Enable detailed monitoring and logging"
  type        = bool
  default     = true
}

variable "access_logs_enabled" {
  description = "Enable CloudFront access logs"
  type        = bool
  default     = false
}

# Security Configuration
variable "delete_protection" {
  description = "Enable deletion protection for critical resources"
  type        = bool
  default     = false
}

# Tags
variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
