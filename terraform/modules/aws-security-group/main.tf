# AWS Security Group Module - Network Security Rules
# Cost: Free (no charges for security groups)
# Features: Ingress/Egress rules, Protocol support, CIDR/SG references

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
resource "random_id" "sg_suffix" {
  count       = var.use_random_suffix ? 1 : 0
  byte_length = 4
}

# Local values for consistent naming and tagging
locals {
  sg_name = var.use_random_suffix ? "${var.name}-${random_id.sg_suffix[0].hex}" : var.name
  
  common_tags = merge(var.tags, {
    Name        = local.sg_name
    Environment = var.environment
    ManagedBy   = "terraform"
    CostCenter  = "development"
    Service     = "security-group"
    CreatedBy   = "internal-developer-platform"
    CreatedAt   = timestamp()
  })

  # Default ingress rules for common services
  default_ingress_rules = {
    ssh = {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "SSH access"
    }
    http = {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "HTTP access"
    }
    https = {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "HTTPS access"
    }
    mysql = {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      description = "MySQL/MariaDB access"
    }
    postgres = {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL access"
    }
    redis = {
      from_port   = 6379
      to_port     = 6379
      protocol    = "tcp"
      description = "Redis access"
    }
    mongodb = {
      from_port   = 27017
      to_port     = 27017
      protocol    = "tcp"
      description = "MongoDB access"
    }
    elasticsearch = {
      from_port   = 9200
      to_port     = 9200
      protocol    = "tcp"
      description = "Elasticsearch access"
    }
    kibana = {
      from_port   = 5601
      to_port     = 5601
      protocol    = "tcp"
      description = "Kibana access"
    }
    grafana = {
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      description = "Grafana access"
    }
  }

  # Process ingress rules from presets and custom rules
  processed_ingress_rules = concat(
    # Preset rules
    [
      for preset in var.ingress_presets : merge(
        local.default_ingress_rules[preset],
        {
          cidr_blocks                = var.allowed_cidr_blocks
          source_security_group_ids  = var.allowed_security_group_ids
          prefix_list_ids           = var.allowed_prefix_list_ids
          self                      = false
        }
      )
    ],
    # Custom rules
    var.ingress_rules
  )

  # Process egress rules (default allow all if none specified)
  processed_egress_rules = length(var.egress_rules) > 0 ? var.egress_rules : [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "All outbound traffic"
      source_security_group_ids = []
      prefix_list_ids = []
      self = false
    }
  ]
}

# Get VPC information
data "aws_vpc" "selected" {
  id      = var.vpc_id != "" ? var.vpc_id : null
  default = var.vpc_id == "" ? true : false
}

# Main Security Group
resource "aws_security_group" "main" {
  name_prefix = "${local.sg_name}-"
  description = var.description != "" ? var.description : "Security group for ${local.sg_name}"
  vpc_id      = data.aws_vpc.selected.id

  # Revoke default egress rule if we have custom egress rules
  revoke_rules_on_delete = var.revoke_rules_on_delete

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# Ingress Rules
resource "aws_security_group_rule" "ingress" {
  count = length(local.processed_ingress_rules)

  type              = "ingress"
  security_group_id = aws_security_group.main.id

  from_port = local.processed_ingress_rules[count.index].from_port
  to_port   = local.processed_ingress_rules[count.index].to_port
  protocol  = local.processed_ingress_rules[count.index].protocol

  # CIDR blocks
  cidr_blocks = lookup(local.processed_ingress_rules[count.index], "cidr_blocks", null)

  # IPv6 CIDR blocks
  ipv6_cidr_blocks = lookup(local.processed_ingress_rules[count.index], "ipv6_cidr_blocks", null)

  # Source security group IDs
  source_security_group_id = length(lookup(local.processed_ingress_rules[count.index], "source_security_group_ids", [])) == 1 ? lookup(local.processed_ingress_rules[count.index], "source_security_group_ids", [])[0] : null

  # Prefix list IDs
  prefix_list_ids = lookup(local.processed_ingress_rules[count.index], "prefix_list_ids", null)

  # Self reference
  self = lookup(local.processed_ingress_rules[count.index], "self", false)

  # Description
  description = lookup(local.processed_ingress_rules[count.index], "description", "Managed by Terraform")

  lifecycle {
    create_before_destroy = true
  }
}

# Additional ingress rules for multiple source security groups
resource "aws_security_group_rule" "ingress_sg_multiple" {
  for_each = {
    for idx, rule in local.processed_ingress_rules : idx => rule
    if length(lookup(rule, "source_security_group_ids", [])) > 1
  }

  count = length(each.value.source_security_group_ids)

  type              = "ingress"
  security_group_id = aws_security_group.main.id

  from_port = each.value.from_port
  to_port   = each.value.to_port
  protocol  = each.value.protocol

  source_security_group_id = each.value.source_security_group_ids[count.index]
  description = "${lookup(each.value, "description", "Managed by Terraform")} - SG ${count.index + 1}"

  lifecycle {
    create_before_destroy = true
  }
}

# Egress Rules
resource "aws_security_group_rule" "egress" {
  count = length(local.processed_egress_rules)

  type              = "egress"
  security_group_id = aws_security_group.main.id

  from_port = local.processed_egress_rules[count.index].from_port
  to_port   = local.processed_egress_rules[count.index].to_port
  protocol  = local.processed_egress_rules[count.index].protocol

  # CIDR blocks
  cidr_blocks = lookup(local.processed_egress_rules[count.index], "cidr_blocks", null)

  # IPv6 CIDR blocks
  ipv6_cidr_blocks = lookup(local.processed_egress_rules[count.index], "ipv6_cidr_blocks", null)

  # Source security group IDs
  source_security_group_id = length(lookup(local.processed_egress_rules[count.index], "source_security_group_ids", [])) == 1 ? lookup(local.processed_egress_rules[count.index], "source_security_group_ids", [])[0] : null

  # Prefix list IDs
  prefix_list_ids = lookup(local.processed_egress_rules[count.index], "prefix_list_ids", null)

  # Self reference
  self = lookup(local.processed_egress_rules[count.index], "self", false)

  # Description
  description = lookup(local.processed_egress_rules[count.index], "description", "Managed by Terraform")

  lifecycle {
    create_before_destroy = true
  }
}

# Additional egress rules for multiple source security groups
resource "aws_security_group_rule" "egress_sg_multiple" {
  for_each = {
    for idx, rule in local.processed_egress_rules : idx => rule
    if length(lookup(rule, "source_security_group_ids", [])) > 1
  }

  count = length(each.value.source_security_group_ids)

  type              = "egress"
  security_group_id = aws_security_group.main.id

  from_port = each.value.from_port
  to_port   = each.value.to_port
  protocol  = each.value.protocol

  source_security_group_id = each.value.source_security_group_ids[count.index]
  description = "${lookup(each.value, "description", "Managed by Terraform")} - SG ${count.index + 1}"

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for common database access pattern
resource "aws_security_group" "database" {
  count = var.create_database_sg ? 1 : 0
  
  name_prefix = "${local.sg_name}-db-"
  description = "Database security group for ${local.sg_name}"
  vpc_id      = data.aws_vpc.selected.id

  # Allow access from main security group
  ingress {
    from_port       = var.database_port
    to_port         = var.database_port
    protocol        = "tcp"
    security_groups = [aws_security_group.main.id]
    description     = "Database access from application security group"
  }

  tags = merge(local.common_tags, {
    Name = "${local.sg_name}-database"
    Type = "database"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for load balancer pattern
resource "aws_security_group" "load_balancer" {
  count = var.create_load_balancer_sg ? 1 : 0
  
  name_prefix = "${local.sg_name}-lb-"
  description = "Load balancer security group for ${local.sg_name}"
  vpc_id      = data.aws_vpc.selected.id

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.load_balancer_cidr_blocks
    description = "HTTP access to load balancer"
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.load_balancer_cidr_blocks
    description = "HTTPS access to load balancer"
  }

  # Outbound to application
  egress {
    from_port       = var.application_port
    to_port         = var.application_port
    protocol        = "tcp"
    security_groups = [aws_security_group.main.id]
    description     = "Access to application from load balancer"
  }

  tags = merge(local.common_tags, {
    Name = "${local.sg_name}-load-balancer"
    Type = "load-balancer"
  })

  lifecycle {
    create_before_destroy = true
  }
}
