# API Simple Module Variables
# Complete variable definitions for the simple API service template

variable "api_name" {
  description = "Name of the API service (3-50 characters, alphanumeric and hyphens only)"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{3,50}$", var.api_name))
    error_message = "API name must be 3-50 characters long and contain only alphanumeric characters and hyphens."
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

variable "runtime" {
  description = "Programming language/runtime for the API"
  type        = string
  default     = "nodejs"
  
  validation {
    condition     = contains(["nodejs", "python", "java", "go"], var.runtime)
    error_message = "Runtime must be one of: nodejs, python, java, go."
  }
}

variable "instance_type" {
  description = "EC2 instance type for the API server"
  type        = string
  default     = "t2.micro"
  
  validation {
    condition     = contains(["t2.micro", "t2.small", "t3.micro", "t3.small"], var.instance_type)
    error_message = "Instance type must be one of the cost-optimized types: t2.micro, t2.small, t3.micro, t3.small."
  }
}

variable "database_required" {
  description = "Whether to provision a database for this API"
  type        = bool
  default     = false
}

variable "database_type" {
  description = "Database engine type (only used if database_required is true)"
  type        = string
  default     = "postgres"
  
  validation {
    condition     = contains(["postgres", "mysql"], var.database_type)
    error_message = "Database type must be either 'postgres' or 'mysql'."
  }
}

variable "redis_cache" {
  description = "Whether to include Redis for caching"
  type        = bool
  default     = false
}

variable "load_balancer" {
  description = "Whether to enable load balancer"
  type        = bool
  default     = false
}

variable "auto_scaling" {
  description = "Whether to enable auto-scaling"
  type        = bool
  default     = false
}

variable "monitoring_enabled" {
  description = "Whether to enable CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "backup_enabled" {
  description = "Whether to enable automated backups"
  type        = bool
  default     = false
}

variable "api_gateway" {
  description = "Whether to use API Gateway instead of direct EC2 access"
  type        = bool
  default     = false
}

variable "ssl_enabled" {
  description = "Whether to enable SSL/TLS (requires domain)"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Custom domain name for the API (optional)"
  type        = string
  default     = ""
}

variable "allowed_ips" {
  description = "List of IP addresses/CIDR blocks allowed to access the API"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "api_port" {
  description = "Port on which the API will run"
  type        = number
  default     = 3000
  
  validation {
    condition     = var.api_port > 0 && var.api_port < 65536
    error_message = "API port must be between 1 and 65535."
  }
}

variable "health_check_path" {
  description = "Health check endpoint path"
  type        = string
  default     = "/health"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-west-2"
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
}

# Cost optimization variables
variable "max_cost_per_month" {
  description = "Maximum estimated cost per month in USD"
  type        = number
  default     = 5
  
  validation {
    condition     = var.max_cost_per_month >= 0 && var.max_cost_per_month <= 100
    error_message = "Maximum cost must be between 0 and 100 USD per month."
  }
}

variable "delete_protection" {
  description = "Enable deletion protection for production resources"
  type        = bool
  default     = false
}
