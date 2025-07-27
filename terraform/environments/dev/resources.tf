# Development Environment - Dynamic Resource Processing
# This file dynamically creates resources based on pending requests

# S3 Buckets
module "s3_instances" {
  source = "../../modules/s3"
  
  for_each = {
    for id, request in var.instance_requests : id => request
    if request.resource_type == "s3"
  }
  
  # Pass the resource configuration to the module
  bucket_name         = each.value.resource_config.bucket_name
  versioning_enabled  = try(each.value.resource_config.versioning_enabled, false)
  encryption_enabled  = try(each.value.resource_config.encryption_enabled, true)
  public_read_access  = try(each.value.resource_config.public_read_access, false)
  lifecycle_rules     = try(each.value.resource_config.lifecycle_rules, [])
  
  # Add common tags plus requester info
  tags = merge(
    local.common_tags,
    try(each.value.resource_config.tags, {}),
    {
      RequestId = each.key
      Requester = each.value.requester
    }
  )
}

# EC2 Instances
module "ec2_instances" {
  source = "../../modules/ec2"
  
  for_each = {
    for id, request in var.instance_requests : id => request
    if request.resource_type == "ec2"
  }
  
  # Pass the resource configuration to the module
  instance_type      = each.value.resource_config.instance_type
  ami_id            = each.value.resource_config.ami_id
  key_pair_name     = each.value.resource_config.key_pair_name
  security_group_ids = try(each.value.resource_config.security_group_ids, [])
  subnet_id         = try(each.value.resource_config.subnet_id, null)
  user_data         = try(each.value.resource_config.user_data, null)
  
  # Add common tags plus requester info
  tags = merge(
    local.common_tags,
    try(each.value.resource_config.tags, {}),
    {
      RequestId = each.key
      Requester = each.value.requester
    }
  )
}

# VPC Networks
module "vpc_instances" {
  source = "../../modules/vpc"
  
  for_each = {
    for id, request in var.instance_requests : id => request
    if request.resource_type == "vpc"
  }
  
  # Pass the resource configuration to the module
  cidr_block           = each.value.resource_config.cidr_block
  enable_dns_hostnames = try(each.value.resource_config.enable_dns_hostnames, true)
  enable_dns_support   = try(each.value.resource_config.enable_dns_support, true)
  availability_zones   = each.value.resource_config.availability_zones
  public_subnet_cidrs  = each.value.resource_config.public_subnet_cidrs
  private_subnet_cidrs = each.value.resource_config.private_subnet_cidrs
  
  # Add common tags plus requester info
  tags = merge(
    local.common_tags,
    try(each.value.resource_config.tags, {}),
    {
      RequestId = each.key
      Requester = each.value.requester
    }
  )
}
