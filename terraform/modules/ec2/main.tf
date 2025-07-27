# EC2 Instance Terraform Module

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Input Variables
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "Amazon Machine Image ID"
  type        = string
}

variable "key_pair_name" {
  description = "SSH key pair name"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
  default     = []
}

variable "subnet_id" {
  description = "Subnet ID for instance placement"
  type        = string
  default     = null
}

variable "user_data" {
  description = "User data script"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# EC2 Instance Resource
resource "aws_instance" "main" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name              = var.key_pair_name
  vpc_security_group_ids = var.security_group_ids
  subnet_id             = var.subnet_id
  user_data             = var.user_data

  tags = merge(var.tags, {
    Name = "ec2-${random_id.instance_suffix.hex}"
  })
}

# Random suffix for unique naming
resource "random_id" "instance_suffix" {
  byte_length = 4
}

# Outputs
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.main.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.main.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.main.private_ip
}

output "instance_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.main.public_dns
}
