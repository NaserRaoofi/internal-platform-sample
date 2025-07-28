# API Simple Module Outputs
# Comprehensive outputs for the deployed API service

output "api_info" {
  description = "Complete API service information"
  value = {
    api_id          = local.api_id
    api_name        = var.api_name
    environment     = var.environment
    runtime         = var.runtime
    status          = "deployed"
    deployment_time = timestamp()
  }
}

output "endpoints" {
  description = "API service endpoints"
  value = {
    public_ip      = aws_instance.api_server.public_ip
    private_ip     = aws_instance.api_server.private_ip
    public_dns     = aws_instance.api_server.public_dns
    api_url        = "http://${aws_instance.api_server.public_ip}:${var.api_port}"
    health_check   = "http://${aws_instance.api_server.public_ip}:${var.api_port}${var.health_check_path}"
    ssh_access     = "ssh ec2-user@${aws_instance.api_server.public_ip}"
  }
}

output "security" {
  description = "Security configuration details"
  value = {
    security_group_id = aws_security_group.api_server.id
    allowed_ports     = [22, 80, var.api_port]
    allowed_ips       = var.allowed_ips
    ssl_enabled       = var.ssl_enabled
  }
}

output "infrastructure" {
  description = "Infrastructure details"
  value = {
    instance_id       = aws_instance.api_server.id
    instance_type     = aws_instance.api_server.instance_type
    availability_zone = aws_instance.api_server.availability_zone
    ami_id           = aws_instance.api_server.ami
    key_name         = aws_instance.api_server.key_name
  }
}

output "database" {
  description = "Database connection details (if enabled)"
  value = var.database_required ? {
    enabled          = true
    database_id      = aws_db_instance.api_database[0].id
    database_name    = aws_db_instance.api_database[0].db_name
    username         = aws_db_instance.api_database[0].username
    endpoint         = aws_db_instance.api_database[0].endpoint
    port            = aws_db_instance.api_database[0].port
    engine          = aws_db_instance.api_database[0].engine
    engine_version  = aws_db_instance.api_database[0].engine_version
    connection_string = "${aws_db_instance.api_database[0].engine}://${aws_db_instance.api_database[0].username}:[PASSWORD]@${aws_db_instance.api_database[0].endpoint}:${aws_db_instance.api_database[0].port}/${aws_db_instance.api_database[0].db_name}"
  } : {
    enabled = false
    message = "Database not requested for this API service"
  }
}

output "monitoring" {
  description = "Monitoring and logging configuration"
  value = {
    cloudwatch_enabled = var.monitoring_enabled
    log_group         = var.monitoring_enabled ? "/aws/ec2/${local.api_id}" : null
    metrics_namespace = "CustomAPI/${var.api_name}"
  }
}

output "cost_estimate" {
  description = "Estimated monthly costs (USD)"
  value = {
    ec2_instance     = var.instance_type == "t2.micro" ? 0 : (var.instance_type == "t3.micro" ? 7.59 : 15.18)
    database         = var.database_required ? 12.00 : 0
    storage          = 2.00
    data_transfer    = 1.00
    total_estimated  = (var.instance_type == "t2.micro" ? 0 : (var.instance_type == "t3.micro" ? 7.59 : 15.18)) + (var.database_required ? 12.00 : 0) + 3.00
    free_tier_eligible = var.instance_type == "t2.micro" && !var.database_required
  }
}

output "deployment_commands" {
  description = "Commands to deploy and manage your API"
  value = {
    ssh_connect     = "ssh -i ~/.ssh/your-key.pem ec2-user@${aws_instance.api_server.public_ip}"
    view_logs       = "ssh ec2-user@${aws_instance.api_server.public_ip} 'sudo journalctl -f -u ${var.api_name}'"
    restart_service = "ssh ec2-user@${aws_instance.api_server.public_ip} 'sudo systemctl restart ${var.api_name}'"
    check_status    = "curl ${aws_instance.api_server.public_ip}:${var.api_port}${var.health_check_path}"
  }
}

output "quick_start_guide" {
  description = "Quick start guide for using your API"
  value = {
    api_url = "http://${aws_instance.api_server.public_ip}:${var.api_port}"
    steps = [
      "1. Your API server is now running at http://${aws_instance.api_server.public_ip}:${var.api_port}",
      "2. SSH into the server: ssh ec2-user@${aws_instance.api_server.public_ip}",
      "3. Your ${var.runtime} application should be in /opt/${var.api_name}/",
      "4. Check health: curl http://${aws_instance.api_server.public_ip}:${var.api_port}${var.health_check_path}",
      var.database_required ? "5. Database is available at: ${aws_db_instance.api_database[0].endpoint}" : "5. No database configured"
    ]
  }
}

# Sensitive outputs (marked as sensitive to prevent accidental exposure)
output "database_password" {
  description = "Database password (sensitive)"
  value       = var.database_required ? random_password.db_password[0].result : null
  sensitive   = true
}

output "database_connection_full" {
  description = "Complete database connection string with password (sensitive)"
  value = var.database_required ? {
    host     = aws_db_instance.api_database[0].endpoint
    port     = aws_db_instance.api_database[0].port
    database = aws_db_instance.api_database[0].db_name
    username = aws_db_instance.api_database[0].username
    password = random_password.db_password[0].result
    url      = "${aws_db_instance.api_database[0].engine}://${aws_db_instance.api_database[0].username}:${random_password.db_password[0].result}@${aws_db_instance.api_database[0].endpoint}:${aws_db_instance.api_database[0].port}/${aws_db_instance.api_database[0].db_name}"
  } : null
  sensitive = true
}

output "resource_tags" {
  description = "All resource tags applied"
  value       = local.common_tags
}
