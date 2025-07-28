# AWS EC2 Module Variables

variable "name" {
  description = "Name for the EC2 instance (used in resource naming)"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{1,50}$", var.name))
    error_message = "Name must be 1-50 characters long and contain only alphanumeric characters and hyphens."
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

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
  
  validation {
    condition = can(regex("^[a-z][0-9][a-z]?\\.[a-z0-9]+$", var.instance_type))
    error_message = "Instance type must be a valid EC2 instance type (e.g., t2.micro, t3.small)."
  }
}

variable "ami_id" {
  description = "AMI ID to use for the instance (leave empty to use latest Amazon Linux 2)"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "Name of the AWS key pair to use for SSH access"
  type        = string
  default     = ""
}

variable "security_group_ids" {
  description = "List of security group IDs to associate with the instance"
  type        = list(string)
  default     = []
}

variable "subnet_id" {
  description = "Subnet ID where the instance will be launched"
  type        = string
  default     = ""
}

variable "user_data" {
  description = "User data script to run on instance launch"
  type        = string
  default     = ""
}

variable "monitoring_enabled" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "root_volume_type" {
  description = "Root volume type (gp2, gp3, io1, io2)"
  type        = string
  default     = "gp3"
  
  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2", "sc1", "st1"], var.root_volume_type)
    error_message = "Root volume type must be one of: gp2, gp3, io1, io2, sc1, st1."
  }
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 20
  
  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 1000
    error_message = "Root volume size must be between 8 and 1000 GB."
  }
}

variable "root_volume_encrypted" {
  description = "Encrypt the root volume"
  type        = bool
  default     = true
}

variable "additional_volumes" {
  description = "List of additional EBS volumes to attach"
  type = list(object({
    device_name           = string
    volume_type           = string
    volume_size           = number
    encrypted             = bool
    delete_on_termination = bool
  }))
  default = []
}

variable "source_dest_check" {
  description = "Enable source/destination checking (disable for NAT instances)"
  type        = bool
  default     = true
}

variable "iam_instance_profile" {
  description = "IAM instance profile name to associate with the instance"
  type        = string
  default     = ""
}

variable "instance_purpose" {
  description = "Purpose/role of the instance (web-server, api-server, database, etc.)"
  type        = string
  default     = "general"
}

variable "enable_eip" {
  description = "Attach an Elastic IP to the instance"
  type        = bool
  default     = false
}

variable "enable_cloudwatch_logs" {
  description = "Create CloudWatch log group for instance logs"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 7
  
  validation {
    condition = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be one of the valid CloudWatch retention periods."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
