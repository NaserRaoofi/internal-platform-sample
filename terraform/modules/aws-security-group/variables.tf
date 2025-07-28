# AWS Security Group Module Variables

variable "name" {
  description = "Name for the security group"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{0,62}$", var.name))
    error_message = "Name must start with a letter, be 1-63 characters long, and contain only alphanumeric characters and hyphens."
  }
}

variable "use_random_suffix" {
  description = "Add random suffix to security group name to ensure uniqueness"
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

variable "description" {
  description = "Description for the security group"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "VPC ID (leave empty to use default VPC)"
  type        = string
  default     = ""
}

variable "revoke_rules_on_delete" {
  description = "Revoke all rules when security group is deleted"
  type        = bool
  default     = false
}

# Ingress Configuration - Preset Rules
variable "ingress_presets" {
  description = "List of preset ingress rules (ssh, http, https, mysql, postgres, redis, mongodb, elasticsearch, kibana, grafana)"
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for preset in var.ingress_presets : 
      contains(["ssh", "http", "https", "mysql", "postgres", "redis", "mongodb", "elasticsearch", "kibana", "grafana"], preset)
    ])
    error_message = "Invalid preset. Allowed values: ssh, http, https, mysql, postgres, redis, mongodb, elasticsearch, kibana, grafana."
  }
}

# Ingress Configuration - Custom Rules
variable "ingress_rules" {
  description = "List of custom ingress rules"
  type = list(object({
    from_port                 = number
    to_port                   = number
    protocol                  = string
    cidr_blocks              = optional(list(string))
    ipv6_cidr_blocks         = optional(list(string))
    source_security_group_ids = optional(list(string), [])
    prefix_list_ids          = optional(list(string))
    self                     = optional(bool, false)
    description              = optional(string, "Managed by Terraform")
  }))
  default = []
}

# Egress Configuration
variable "egress_rules" {
  description = "List of egress rules (if empty, allows all outbound traffic)"
  type = list(object({
    from_port                 = number
    to_port                   = number
    protocol                  = string
    cidr_blocks              = optional(list(string))
    ipv6_cidr_blocks         = optional(list(string))
    source_security_group_ids = optional(list(string), [])
    prefix_list_ids          = optional(list(string))
    self                     = optional(bool, false)
    description              = optional(string, "Managed by Terraform")
  }))
  default = []
}

# Common Source Configuration for Presets
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed for preset rules"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed for preset rules"
  type        = list(string)
  default     = []
}

variable "allowed_prefix_list_ids" {
  description = "Prefix list IDs allowed for preset rules"
  type        = list(string)
  default     = []
}

# Database Security Group Pattern
variable "create_database_sg" {
  description = "Create additional security group for database access pattern"
  type        = bool
  default     = false
}

variable "database_port" {
  description = "Database port for database security group"
  type        = number
  default     = 5432
  
  validation {
    condition     = var.database_port >= 1 && var.database_port <= 65535
    error_message = "Database port must be between 1 and 65535."
  }
}

# Load Balancer Security Group Pattern
variable "create_load_balancer_sg" {
  description = "Create additional security group for load balancer access pattern"
  type        = bool
  default     = false
}

variable "load_balancer_cidr_blocks" {
  description = "CIDR blocks allowed for load balancer access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "application_port" {
  description = "Application port for load balancer to application communication"
  type        = number
  default     = 8080
  
  validation {
    condition     = var.application_port >= 1 && var.application_port <= 65535
    error_message = "Application port must be between 1 and 65535."
  }
}

# Tags
variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
