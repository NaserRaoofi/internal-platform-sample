# Simple API Service Template - Modular and Self-Contained
# Cost: $0-5/month (AWS Free Tier optimized)
# Supports: Node.js, Python, Java, Go with optional database

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
resource "random_id" "api_suffix" {
  byte_length = 4
}

# Local values for consistent naming and tagging
locals {
  api_id = "${var.api_name}-${random_id.api_suffix.hex}"
  
  common_tags = merge(var.tags, {
    Name        = local.api_id
    ApiName     = var.api_name
    Runtime     = var.runtime
    Environment = var.environment
    Template    = "api-simple"
    ManagedBy   = "terraform"
    CostCenter  = "development"
    CreatedBy   = "internal-developer-platform"
    CreatedAt   = timestamp()
  })
  
  # Security group rules for different configurations
  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ips
      description = "SSH access"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = var.allowed_ips
      description = "HTTP access via nginx"
    },
    {
      from_port   = var.api_port
      to_port     = var.api_port
      protocol    = "tcp"
      cidr_blocks = var.allowed_ips
      description = "Direct API access"
    }
  ]
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

# EC2 Instance for API Server
resource "aws_instance" "api_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.api_server.id]
  
  # User data script with all variables
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    api_name    = var.api_name
    runtime     = var.runtime
    api_port    = var.api_port
    environment = var.environment
  }))
  
  # Enable detailed monitoring if requested
  monitoring = var.monitoring_enabled
  
  # Root volume configuration
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
    
    tags = merge(local.common_tags, {
      Name = "${local.api_id}-root-volume"
    })
  }
  
  # Instance metadata options for security
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.api_id}-server"
    Type = "api-server"
  })
  
  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for API Server
resource "aws_security_group" "api_server" {
  name_prefix = "${local.api_id}-api-"
  description = "Security group for ${var.api_name} API service"

  # Dynamic ingress rules
  dynamic "ingress" {
    for_each = local.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  # Outbound traffic (all allowed for package installation and updates)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "${local.api_id}-api-sg"
  })
}

# Optional Database Resources (only created if database_required = true)
resource "random_password" "db_password" {
  count   = var.database_required ? 1 : 0
  length  = 16
  special = true
}

# Get default VPC for database subnet group
data "aws_vpc" "default" {
  count   = var.database_required ? 1 : 0
  default = true
}

data "aws_subnets" "default" {
  count = var.database_required ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }
}

# Database subnet group
resource "aws_db_subnet_group" "api_database" {
  count      = var.database_required ? 1 : 0
  name       = "${local.api_id}-db-subnet-group"
  subnet_ids = data.aws_subnets.default[0].ids
  
  tags = merge(local.common_tags, {
    Name = "${local.api_id}-db-subnet-group"
  })
}

# Database security group
resource "aws_security_group" "database" {
  count       = var.database_required ? 1 : 0
  name_prefix = "${local.api_id}-db-"
  description = "Security group for ${var.api_name} database"

  ingress {
    from_port       = var.database_type == "postgres" ? 5432 : 3306
    to_port         = var.database_type == "postgres" ? 5432 : 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.api_server.id]
    description     = "${var.database_type} database access from API server"
  }

  tags = merge(local.common_tags, {
    Name = "${local.api_id}-db-sg"
  })
}

# RDS Database instance
resource "aws_db_instance" "api_database" {
  count = var.database_required ? 1 : 0
  
  # Basic configuration
  identifier     = "${local.api_id}-db"
  engine         = var.database_type
  engine_version = var.database_type == "postgres" ? "14.9" : "8.0.35"
  instance_class = "db.t3.micro"
  
  # Storage configuration
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  
  # Database configuration
  db_name  = replace(var.api_name, "-", "_")
  username = "apiuser"
  password = random_password.db_password[0].result
  port     = var.database_type == "postgres" ? 5432 : 3306
  
  # Network configuration
  vpc_security_group_ids = [aws_security_group.database[0].id]
  db_subnet_group_name   = aws_db_subnet_group.api_database[0].name
  publicly_accessible    = false
  
  # Backup configuration
  backup_retention_period   = var.backup_enabled ? 7 : 1
  backup_window            = "03:00-04:00"
  maintenance_window       = "Sun:04:00-Sun:05:00"
  auto_minor_version_upgrade = true
  
  # Security and lifecycle
  skip_final_snapshot       = !var.delete_protection
  deletion_protection       = var.delete_protection
  copy_tags_to_snapshot     = true
  
  # Performance insights (free tier)
  performance_insights_enabled = true
  performance_insights_retention_period = 7
  
  # Monitoring
  monitoring_interval = var.monitoring_enabled ? 60 : 0
  monitoring_role_arn = var.monitoring_enabled ? aws_iam_role.rds_monitoring[0].arn : null
  
  tags = merge(local.common_tags, {
    Name = "${local.api_id}-database"
    Type = "database"
  })
}

# IAM role for RDS monitoring (if monitoring enabled)
resource "aws_iam_role" "rds_monitoring" {
  count = var.database_required && var.monitoring_enabled ? 1 : 0
  name  = "${local.api_id}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count      = var.database_required && var.monitoring_enabled ? 1 : 0
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# CloudWatch Log Group for application logs (if monitoring enabled)
resource "aws_cloudwatch_log_group" "api_logs" {
  count             = var.monitoring_enabled ? 1 : 0
  name              = "/aws/ec2/${local.api_id}"
  retention_in_days = var.environment == "prod" ? 30 : 7
  
  tags = merge(local.common_tags, {
    Name = "${local.api_id}-logs"
  })
}
