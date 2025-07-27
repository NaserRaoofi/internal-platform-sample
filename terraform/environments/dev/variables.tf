# Development Environment Variables

variable "aws_region" {
  description = "AWS region for development environment"
  type        = string
  default     = "us-east-1"
}

variable "instance_requests" {
  description = "Map of instance requests to process"
  type = map(object({
    resource_type   = string
    resource_config = any
    requester      = string
  }))
  default = {}
}

# Output values
output "processed_requests" {
  description = "Information about processed requests"
  value = {
    s3_buckets = try(module.s3_instances, {})
    ec2_instances = try(module.ec2_instances, {})
    vpc_networks = try(module.vpc_instances, {})
  }
}
