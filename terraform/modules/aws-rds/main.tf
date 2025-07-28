# AWS RDS Module
# Reusable module for creating RDS database instances

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

# Random password for database
resource "random_password" "db_password" {
  count   = var.manage_master_user_password ? 0 : 1
  length  = var.password_length
  special = true
}

# Random suffix for unique names
resource "random_id" "db_suffix" {
  byte_length = 4
}

locals {
  db_identifier = var.use_random_suffix ? "${var.identifier}-${random_id.db_suffix.hex}" : var.identifier
  
  common_tags = merge(var.tags, {
    Name        = local.db_identifier
    Module      = "aws-rds"
    Environment = var.environment
    Engine      = var.engine
    ManagedBy   = "terraform"
  })
}

# Get default VPC and subnets if not specified
data "aws_vpc" "default" {
  count   = var.vpc_id == "" ? 1 : 0
  default = true
}

data "aws_subnets" "default" {
  count = var.subnet_ids == null ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default[0].id]
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  count      = var.db_subnet_group_name == "" ? 1 : 0
  name       = "${local.db_identifier}-subnet-group"
  subnet_ids = var.subnet_ids != null ? var.subnet_ids : data.aws_subnets.default[0].ids
  
  tags = merge(local.common_tags, {
    Name = "${local.db_identifier}-subnet-group"
    Type = "db-subnet-group"
  })
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  count       = var.security_group_ids == null ? 1 : 0
  name_prefix = "${local.db_identifier}-rds-"
  description = "Security group for ${local.db_identifier} RDS instance"
  vpc_id      = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default[0].id

  dynamic "ingress" {
    for_each = var.allowed_security_groups
    content {
      from_port       = var.port
      to_port         = var.port
      protocol        = "tcp"
      security_groups = [ingress.value]
      description     = "Database access from security group ${ingress.value}"
    }
  }

  dynamic "ingress" {
    for_each = var.allowed_cidr_blocks
    content {
      from_port   = var.port
      to_port     = var.port
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "Database access from ${ingress.value}"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "${local.db_identifier}-sg"
    Type = "security-group"
  })
}

# RDS Instance
resource "aws_db_instance" "main" {
  # Basic Configuration
  identifier     = local.db_identifier
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class
  
  # Storage Configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id           = var.kms_key_id
  
  # Database Configuration
  db_name  = var.database_name
  username = var.username
  password = var.manage_master_user_password ? null : (var.password != "" ? var.password : random_password.db_password[0].result)
  port     = var.port
  
  # Network Configuration
  db_subnet_group_name   = var.db_subnet_group_name != "" ? var.db_subnet_group_name : aws_db_subnet_group.main[0].name
  vpc_security_group_ids = var.security_group_ids != null ? var.security_group_ids : [aws_security_group.rds[0].id]
  publicly_accessible    = var.publicly_accessible
  
  # Backup Configuration
  backup_retention_period   = var.backup_retention_period
  backup_window            = var.backup_window
  copy_tags_to_snapshot    = true
  delete_automated_backups = var.delete_automated_backups
  
  # Maintenance Configuration
  maintenance_window         = var.maintenance_window
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  allow_major_version_upgrade = var.allow_major_version_upgrade
  
  # Security Configuration
  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.db_identifier}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  
  # Performance Configuration
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null
  performance_insights_kms_key_id      = var.performance_insights_enabled && var.performance_insights_kms_key_id != "" ? var.performance_insights_kms_key_id : null
  
  # Monitoring Configuration
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? (var.monitoring_role_arn != "" ? var.monitoring_role_arn : aws_iam_role.rds_monitoring[0].arn) : null
  
  # Enhanced Monitoring
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  
  # Multi-AZ
  multi_az = var.multi_az
  
  # Parameter Group
  parameter_group_name = var.parameter_group_name
  
  # Option Group
  option_group_name = var.option_group_name
  
  # Tags
  tags = local.common_tags
  
  # Manage master user password (RDS managed)
  manage_master_user_password = var.manage_master_user_password
  
  lifecycle {
    ignore_changes = [
      password, # Ignore password changes to prevent drift
    ]
  }
}

# IAM Role for Enhanced Monitoring (if monitoring_interval > 0)
resource "aws_iam_role" "rds_monitoring" {
  count = var.monitoring_interval > 0 && var.monitoring_role_arn == "" ? 1 : 0
  name  = "${local.db_identifier}-rds-monitoring"

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
  count      = var.monitoring_interval > 0 && var.monitoring_role_arn == "" ? 1 : 0
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
