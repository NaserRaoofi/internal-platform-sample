# Terraform Modular Structure

This directory contains a modular Terraform structure designed for the Internal Developer Platform. Each AWS service is separated into its own reusable module, and application templates combine these modules to create complete solutions.

## Structure

```
terraform/
├── modules/                    # Reusable service modules
│   ├── aws-ec2/               # EC2 instances
│   ├── aws-s3/                # S3 buckets  
│   ├── aws-rds/               # RDS databases
│   ├── aws-cloudfront/        # CloudFront distributions
│   └── aws-security-group/    # Security groups
├── templates/                 # Application templates
│   ├── web-app-simple/        # Simple web application
│   └── api-simple/            # Simple API service
└── environments/              # Environment-specific configurations
    ├── dev/
    ├── staging/
    └── prod/
```

## Service Modules

### AWS EC2 Module (`modules/aws-ec2/`)
- **Purpose**: Creates EC2 instances with configurable settings
- **Features**: 
  - Multiple instance types
  - Custom user data scripts
  - Security group configuration
  - EBS volume management
  - CloudWatch monitoring
  - Elastic IP support

### AWS S3 Module (`modules/aws-s3/`)
- **Purpose**: Creates S3 buckets for various use cases
- **Features**:
  - Static website hosting
  - Versioning and encryption
  - Lifecycle policies
  - CORS configuration
  - Public/private access control

### AWS RDS Module (`modules/aws-rds/`)
- **Purpose**: Creates managed database instances
- **Features**:
  - Multiple database engines (PostgreSQL, MySQL)
  - Backup and recovery
  - Performance monitoring
  - Security group integration
  - Multi-AZ deployment

## Application Templates

### Web App Simple (`templates/web-app-simple/`)
Combines multiple services for a complete web application:
- **Frontend**: S3 bucket with static website hosting
- **Backend**: EC2 instance for API server (optional)
- **Database**: RDS instance (optional)
- **CDN**: CloudFront distribution (optional)

### API Simple (`templates/api-simple/`)
Lightweight API service template:
- **Compute**: EC2 instance with auto-configuration
- **Database**: RDS instance (optional)
- **Monitoring**: CloudWatch integration

## Usage Examples

### Using Individual Modules

```hcl
# Create an EC2 instance
module "web_server" {
  source = "./modules/aws-ec2"
  
  name              = "my-web-server"
  instance_type     = "t2.micro"
  environment       = "dev"
  instance_purpose  = "web-server"
  
  tags = {
    Project = "MyApp"
  }
}

# Create an S3 bucket
module "static_website" {
  source = "./modules/aws-s3"
  
  bucket_name       = "my-static-site"
  website_enabled   = true
  public_read_access = true
  environment       = "dev"
}
```

### Using Application Templates

```hcl
# Deploy a complete web application
module "my_web_app" {
  source = "./templates/web-app-simple"
  
  app_name           = "my-awesome-app"
  environment        = "dev"
  backend_api        = true
  database_required  = true
  database_type      = "postgres"
  
  tags = {
    Project = "MyApp"
    Owner   = "DevTeam"
  }
}
```

## Benefits of This Structure

1. **Reusability**: Each service module can be used across different applications
2. **Maintainability**: Changes to a service affect all applications using it
3. **Consistency**: Standardized configurations across all deployments
4. **Flexibility**: Mix and match services as needed
5. **Testing**: Each module can be tested independently
6. **Cost Control**: Each module includes cost optimization features

## Best Practices

1. **Version your modules**: Use git tags for module versions
2. **Document modules**: Each module should have comprehensive documentation
3. **Test modules**: Create test cases for each module
4. **Use consistent naming**: Follow naming conventions across all modules
5. **Tag resources**: Apply consistent tagging for cost tracking and management

## Development Workflow

1. **Develop services**: Create or modify individual service modules
2. **Test services**: Test modules independently
3. **Compose templates**: Combine services into application templates
4. **Test templates**: Validate complete application deployments
5. **Deploy**: Use templates for actual deployments

## Cost Optimization

Each module is designed with AWS Free Tier in mind:
- EC2: Uses t2.micro instances by default
- RDS: Uses t3.micro instances with minimal storage
- S3: Configured for standard storage with lifecycle policies
- Monitoring: Basic CloudWatch metrics included

## Security Features

- **Encryption**: All storage encrypted by default
- **Network Security**: Proper security group configurations
- **IAM**: Least privilege access patterns
- **VPC**: Secure network configurations

## Future Enhancements

Planned additions:
- AWS Lambda module
- AWS API Gateway module  
- AWS CloudWatch module
- AWS ELB module
- Kubernetes deployment templates
- CI/CD pipeline templates
