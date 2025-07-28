# AWS EC2 Module
# Reusable module for creating EC2 instances

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

# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Random suffix for unique names
resource "random_id" "instance_suffix" {
  byte_length = 4
}

locals {
  instance_name = "${var.name}-${random_id.instance_suffix.hex}"
  
  common_tags = merge(var.tags, {
    Name        = local.instance_name
    Module      = "aws-ec2"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# EC2 Instance
resource "aws_instance" "main" {
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name              = var.key_name
  vpc_security_group_ids = var.security_group_ids
  subnet_id             = var.subnet_id
  
  # User data script
  user_data = var.user_data
  
  # Enable detailed monitoring if requested
  monitoring = var.monitoring_enabled
  
  # Root volume configuration
  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    encrypted             = var.root_volume_encrypted
    delete_on_termination = true
    
    tags = merge(local.common_tags, {
      Name = "${local.instance_name}-root"
      Type = "root-volume"
    })
  }
  
  # Additional EBS volumes
  dynamic "ebs_block_device" {
    for_each = var.additional_volumes
    content {
      device_name           = ebs_block_device.value.device_name
      volume_type           = ebs_block_device.value.volume_type
      volume_size           = ebs_block_device.value.volume_size
      encrypted             = ebs_block_device.value.encrypted
      delete_on_termination = ebs_block_device.value.delete_on_termination
      
      tags = merge(local.common_tags, {
        Name = "${local.instance_name}-${ebs_block_device.value.device_name}"
        Type = "additional-volume"
      })
    }
  }
  
  # Instance metadata options for security
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }
  
  # Disable source/destination checking if requested (for NAT instances)
  source_dest_check = var.source_dest_check
  
  # IAM instance profile
  iam_instance_profile = var.iam_instance_profile
  
  tags = merge(local.common_tags, {
    Type = var.instance_purpose
  })
  
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      ami, # Allow AMI updates without forcing replacement
    ]
  }
}

# Elastic IP (optional)
resource "aws_eip" "main" {
  count = var.enable_eip ? 1 : 0
  
  instance = aws_instance.main.id
  domain   = "vpc"
  
  tags = merge(local.common_tags, {
    Name = "${local.instance_name}-eip"
    Type = "elastic-ip"
  })
  
  depends_on = [aws_instance.main]
}

# CloudWatch Log Group for instance logs (optional)
resource "aws_cloudwatch_log_group" "instance_logs" {
  count = var.enable_cloudwatch_logs ? 1 : 0
  
  name              = "/aws/ec2/${local.instance_name}"
  retention_in_days = var.log_retention_days
  
  tags = merge(local.common_tags, {
    Name = "${local.instance_name}-logs"
    Type = "log-group"
  })
}
