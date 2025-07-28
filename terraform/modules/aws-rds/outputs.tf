# AWS RDS Module Outputs

# RDS Instance Outputs
output "db_instance_id" {
  description = "The RDS instance identifier"
  value       = aws_db_instance.main.identifier
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = aws_db_instance.main.arn
}

output "db_instance_address" {
  description = "The address of the RDS instance"
  value       = aws_db_instance.main.address
}

output "db_instance_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_port" {
  description = "The database port"
  value       = aws_db_instance.main.port
}

output "db_instance_status" {
  description = "The RDS instance status"
  value       = aws_db_instance.main.status
}

# Database Information
output "database_name" {
  description = "The name of the database"
  value       = aws_db_instance.main.db_name
}

output "database_username" {
  description = "The master username for the database"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "database_password" {
  description = "The master password for the database"
  value       = var.manage_master_user_password ? null : random_password.master_password[0].result
  sensitive   = true
}

# Connection String
output "connection_string" {
  description = "Database connection string"
  value       = "${aws_db_instance.main.engine}://${aws_db_instance.main.username}:${var.manage_master_user_password ? "[MANAGED_BY_AWS]" : random_password.master_password[0].result}@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
  sensitive   = true
}

# Security Group
output "security_group_id" {
  description = "The ID of the RDS security group"
  value       = var.security_group_ids == null ? aws_security_group.rds[0].id : null
}

# Subnet Group
output "db_subnet_group_name" {
  description = "The name of the DB subnet group"
  value       = var.db_subnet_group_name == "" ? aws_db_subnet_group.main[0].name : var.db_subnet_group_name
}

# Monitoring
output "monitoring_role_arn" {
  description = "The ARN of the monitoring role"
  value       = var.monitoring_role_arn == "" && var.monitoring_interval > 0 ? aws_iam_role.rds_enhanced_monitoring[0].arn : var.monitoring_role_arn
}

# Performance Insights
output "performance_insights_enabled" {
  description = "Whether Performance Insights is enabled"
  value       = aws_db_instance.main.performance_insights_enabled
}

# Backup Information
output "backup_retention_period" {
  description = "The backup retention period"
  value       = aws_db_instance.main.backup_retention_period
}

output "backup_window" {
  description = "The backup window"
  value       = aws_db_instance.main.backup_window
}

# Maintenance Information
output "maintenance_window" {
  description = "The maintenance window"
  value       = aws_db_instance.main.maintenance_window
}

# Storage Information
output "allocated_storage" {
  description = "The allocated storage"
  value       = aws_db_instance.main.allocated_storage
}

output "storage_type" {
  description = "The storage type"
  value       = aws_db_instance.main.storage_type
}

output "storage_encrypted" {
  description = "Whether the storage is encrypted"
  value       = aws_db_instance.main.storage_encrypted
}

# Engine Information
output "engine" {
  description = "The database engine"
  value       = aws_db_instance.main.engine
}

output "engine_version" {
  description = "The database engine version"
  value       = aws_db_instance.main.engine_version_actual
}

# Network Information
output "vpc_security_group_ids" {
  description = "The VPC security group IDs"
  value       = aws_db_instance.main.vpc_security_group_ids
}

output "availability_zone" {
  description = "The availability zone of the instance"
  value       = aws_db_instance.main.availability_zone
}

output "multi_az" {
  description = "Whether the instance is multi-AZ"
  value       = aws_db_instance.main.multi_az
}

# Cost Optimization Tags
output "tags" {
  description = "Tags applied to the RDS instance"
  value       = aws_db_instance.main.tags_all
}
