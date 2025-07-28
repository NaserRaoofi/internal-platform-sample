# AWS EC2 Module Outputs

output "instance" {
  description = "Complete EC2 instance information"
  value = {
    id                = aws_instance.main.id
    arn               = aws_instance.main.arn
    instance_state    = aws_instance.main.instance_state
    instance_type     = aws_instance.main.instance_type
    availability_zone = aws_instance.main.availability_zone
    placement_group   = aws_instance.main.placement_group
  }
}

output "network" {
  description = "Network configuration"
  value = {
    public_ip         = aws_instance.main.public_ip
    private_ip        = aws_instance.main.private_ip
    public_dns        = aws_instance.main.public_dns
    private_dns       = aws_instance.main.private_dns
    subnet_id         = aws_instance.main.subnet_id
    vpc_id            = aws_instance.main.vpc_security_group_ids
    elastic_ip        = var.enable_eip ? aws_eip.main[0].public_ip : null
    elastic_ip_id     = var.enable_eip ? aws_eip.main[0].id : null
  }
}

output "security" {
  description = "Security configuration"
  value = {
    security_groups      = aws_instance.main.vpc_security_group_ids
    key_name            = aws_instance.main.key_name
    iam_instance_profile = aws_instance.main.iam_instance_profile
  }
}

output "storage" {
  description = "Storage configuration"
  value = {
    root_device_name = aws_instance.main.root_block_device[0].device_name
    root_volume_id   = aws_instance.main.root_block_device[0].volume_id
    root_volume_size = aws_instance.main.root_block_device[0].volume_size
    root_volume_type = aws_instance.main.root_block_device[0].volume_type
    ebs_volumes      = aws_instance.main.ebs_block_device
  }
}

output "monitoring" {
  description = "Monitoring configuration"
  value = {
    monitoring_enabled = aws_instance.main.monitoring
    cloudwatch_logs    = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.instance_logs[0].name : null
  }
}

output "connection" {
  description = "Connection information for SSH and management"
  value = {
    ssh_command = var.key_name != "" ? "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${var.enable_eip ? aws_eip.main[0].public_ip : aws_instance.main.public_ip}" : null
    public_endpoint = var.enable_eip ? aws_eip.main[0].public_ip : aws_instance.main.public_ip
    private_endpoint = aws_instance.main.private_ip
  }
}

output "tags" {
  description = "Applied tags"
  value = aws_instance.main.tags
}

# Raw outputs for backward compatibility
output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.main.id
}

output "public_ip" {
  description = "Public IP address"
  value       = var.enable_eip ? aws_eip.main[0].public_ip : aws_instance.main.public_ip
}

output "private_ip" {
  description = "Private IP address"
  value       = aws_instance.main.private_ip
}

output "public_dns" {
  description = "Public DNS name"
  value       = aws_instance.main.public_dns
}
