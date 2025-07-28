# AWS Security Group Module Outputs

# Main Security Group
output "security_group_id" {
  description = "The ID of the main security group"
  value       = aws_security_group.main.id
}

output "security_group_arn" {
  description = "The ARN of the main security group"
  value       = aws_security_group.main.arn
}

output "security_group_name" {
  description = "The name of the main security group"
  value       = aws_security_group.main.name
}

output "security_group_description" {
  description = "The description of the main security group"
  value       = aws_security_group.main.description
}

output "security_group_vpc_id" {
  description = "The VPC ID of the main security group"
  value       = aws_security_group.main.vpc_id
}

output "security_group_owner_id" {
  description = "The owner ID of the main security group"
  value       = aws_security_group.main.owner_id
}

# Rule Information
output "ingress_rules" {
  description = "List of ingress rules applied to the security group"
  value = [
    for rule in aws_security_group_rule.ingress : {
      type        = rule.type
      from_port   = rule.from_port
      to_port     = rule.to_port
      protocol    = rule.protocol
      cidr_blocks = rule.cidr_blocks
      description = rule.description
    }
  ]
}

output "egress_rules" {
  description = "List of egress rules applied to the security group"
  value = [
    for rule in aws_security_group_rule.egress : {
      type        = rule.type
      from_port   = rule.from_port
      to_port     = rule.to_port
      protocol    = rule.protocol
      cidr_blocks = rule.cidr_blocks
      description = rule.description
    }
  ]
}

# Rule Counts
output "ingress_rule_count" {
  description = "Number of ingress rules"
  value       = length(aws_security_group_rule.ingress)
}

output "egress_rule_count" {
  description = "Number of egress rules"
  value       = length(aws_security_group_rule.egress)
}

# Database Security Group (if created)
output "database_security_group_id" {
  description = "The ID of the database security group (if created)"
  value       = var.create_database_sg ? aws_security_group.database[0].id : null
}

output "database_security_group_arn" {
  description = "The ARN of the database security group (if created)"
  value       = var.create_database_sg ? aws_security_group.database[0].arn : null
}

output "database_security_group_name" {
  description = "The name of the database security group (if created)"
  value       = var.create_database_sg ? aws_security_group.database[0].name : null
}

# Load Balancer Security Group (if created)
output "load_balancer_security_group_id" {
  description = "The ID of the load balancer security group (if created)"
  value       = var.create_load_balancer_sg ? aws_security_group.load_balancer[0].id : null
}

output "load_balancer_security_group_arn" {
  description = "The ARN of the load balancer security group (if created)"
  value       = var.create_load_balancer_sg ? aws_security_group.load_balancer[0].arn : null
}

output "load_balancer_security_group_name" {
  description = "The name of the load balancer security group (if created)"
  value       = var.create_load_balancer_sg ? aws_security_group.load_balancer[0].name : null
}

# All Security Group IDs (for easy reference)
output "all_security_group_ids" {
  description = "List of all security group IDs created"
  value = compact([
    aws_security_group.main.id,
    var.create_database_sg ? aws_security_group.database[0].id : null,
    var.create_load_balancer_sg ? aws_security_group.load_balancer[0].id : null
  ])
}

# VPC Information
output "vpc_id" {
  description = "The VPC ID where security groups are created"
  value       = data.aws_vpc.selected.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = data.aws_vpc.selected.cidr_block
}

# Security Group References (for use in other resources)
output "security_group_references" {
  description = "Security group references for common use cases"
  value = {
    main_sg_id         = aws_security_group.main.id
    database_sg_id     = var.create_database_sg ? aws_security_group.database[0].id : null
    load_balancer_sg_id = var.create_load_balancer_sg ? aws_security_group.load_balancer[0].id : null
    
    # For EC2 instances
    ec2_security_groups = [aws_security_group.main.id]
    
    # For RDS instances
    rds_security_groups = var.create_database_sg ? [aws_security_group.database[0].id] : [aws_security_group.main.id]
    
    # For Load Balancers
    lb_security_groups = var.create_load_balancer_sg ? [aws_security_group.load_balancer[0].id] : [aws_security_group.main.id]
  }
}

# Configuration Summary
output "configuration_summary" {
  description = "Summary of security group configuration"
  value = {
    name                    = aws_security_group.main.name
    vpc_id                  = aws_security_group.main.vpc_id
    ingress_presets_used    = var.ingress_presets
    custom_ingress_rules    = length(var.ingress_rules)
    custom_egress_rules     = length(var.egress_rules)
    database_sg_created     = var.create_database_sg
    load_balancer_sg_created = var.create_load_balancer_sg
    total_security_groups   = 1 + (var.create_database_sg ? 1 : 0) + (var.create_load_balancer_sg ? 1 : 0)
  }
}

# Cost Information
output "cost_information" {
  description = "Security group cost information"
  value = {
    security_group_cost = "Free - AWS does not charge for security groups"
    rule_cost          = "Free - AWS does not charge for security group rules"
    total_monthly_cost = "$0.00"
    cost_optimization_note = "Security groups are free AWS resources"
  }
}

# Tags Applied
output "tags" {
  description = "Tags applied to the main security group"
  value       = aws_security_group.main.tags_all
}
