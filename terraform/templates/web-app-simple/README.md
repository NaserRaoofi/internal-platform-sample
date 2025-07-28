# Web App Simple Template

A complete web application stack template that combines multiple AWS services to create a scalable, production-ready web application.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   CloudFront    │    │    S3 Bucket     │    │   EC2 Server    │
│     (CDN)       │────│  (Frontend)      │    │   (Backend)     │
│                 │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                                                         ▼
                                                ┌─────────────────┐
                                                │   RDS Database  │
                                                │   (Optional)    │
                                                └─────────────────┘
```

## Components

### Frontend (Always Included)
- **S3 Bucket**: Static website hosting with public read access
- **CORS Configuration**: Proper cross-origin resource sharing setup
- **Website Configuration**: Custom index and error documents

### CDN (Optional - Default: Enabled)
- **CloudFront Distribution**: Global content delivery network
- **HTTPS Support**: SSL/TLS termination with custom certificates
- **Custom Domain**: Support for custom domain names
- **Geo Restrictions**: Optional geographic access controls
- **Cache Optimization**: Optimized caching for web applications

### Backend (Optional - Default: Enabled)
- **EC2 Instance**: Application server with multiple runtime support
- **Auto-scaling Ready**: Prepared for load balancer integration
- **Security Groups**: Properly configured network security
- **Monitoring**: CloudWatch integration for logs and metrics

### Database (Optional - Default: Disabled)
- **RDS Instance**: Managed database service
- **Multi-Engine Support**: PostgreSQL or MySQL
- **Backup Configuration**: Automated backups and maintenance windows
- **Security**: Database subnet groups and security group isolation

## Supported Runtimes

The template supports multiple backend runtimes:

- **Node.js**: Express.js-based API server
- **Python**: Flask-based API server  
- **Go**: Native HTTP server
- **Java**: Simple HTTP server (can be extended to Spring Boot)

## Features

### Security
- ✅ HTTPS enforcement via CloudFront
- ✅ Security groups with least privilege access
- ✅ Database encryption at rest
- ✅ VPC subnet isolation for databases
- ✅ IAM roles and policies

### Cost Optimization
- ✅ AWS Free Tier optimized (t3.micro, db.t3.micro)
- ✅ S3 lifecycle policies for old versions
- ✅ CloudFront PriceClass_100 (lowest cost option)
- ✅ Optional components to minimize costs

### Monitoring
- ✅ CloudWatch logs for application and nginx
- ✅ CloudWatch metrics for system resources
- ✅ Health check endpoints
- ✅ Performance Insights for RDS

### High Availability
- ✅ Multi-AZ RDS deployment option
- ✅ CloudFront global distribution
- ✅ Load balancer ready architecture
- ✅ Auto-scaling group ready

## Usage

### Basic Web Application (Frontend Only)
```hcl
module "web_app" {
  source = "./terraform/templates/web-app-simple"
  
  app_name    = "my-web-app"
  environment = "dev"
  
  # Disable optional components for cost savings
  backend_enabled    = false
  database_required  = false
  cdn_enabled        = true
}
```

### Full Stack Application
```hcl
module "web_app" {
  source = "./terraform/templates/web-app-simple"
  
  app_name    = "my-full-app"
  environment = "prod"
  
  # Frontend
  index_document = "index.html"
  error_document = "error.html"
  
  # Backend
  backend_enabled = true
  runtime         = "nodejs"
  api_port        = 8080
  instance_type   = "t3.micro"
  
  # Database
  database_required      = true
  database_type         = "postgres"
  database_instance_class = "db.t3.micro"
  database_storage_size  = 20
  
  # CDN
  cdn_enabled = true
  custom_domain = "myapp.example.com"
  ssl_certificate_arn = "arn:aws:acm:us-east-1:123456789:certificate/abc123"
  
  # Security
  allowed_cidr_blocks = ["10.0.0.0/8", "192.168.1.0/24"]
  
  # Monitoring
  monitoring_enabled = true
  backup_enabled     = true
  
  tags = {
    Project = "MyWebApp"
    Owner   = "DevTeam"
  }
}
```

## Variables

### Required Variables
- `app_name`: Name of the web application

### Frontend Variables
- `index_document`: Index document (default: "index.html")
- `error_document`: Error document (default: "error.html") 
- `cors_allowed_origins`: CORS allowed origins (default: ["*"])

### Backend Variables
- `backend_enabled`: Enable backend server (default: true)
- `runtime`: Runtime for API server (nodejs|python|go|java, default: "nodejs")
- `api_port`: API server port (default: 8080)
- `instance_type`: EC2 instance type (default: "t3.micro")

### Database Variables
- `database_required`: Enable database (default: false)
- `database_type`: Database engine (postgres|mysql, default: "postgres")
- `database_instance_class`: RDS instance class (default: "db.t3.micro")
- `database_storage_size`: Storage size in GB (default: 20)

### CDN Variables
- `cdn_enabled`: Enable CloudFront CDN (default: true)
- `custom_domain`: Custom domain name (optional)
- `ssl_certificate_arn`: ACM certificate ARN (optional)
- `cdn_price_class`: Price class (default: "PriceClass_100")

## Outputs

### Access URLs
- `application_urls`: All application access URLs
- `frontend_bucket_website_endpoint`: S3 website endpoint
- `cdn_distribution_url`: CloudFront distribution URL

### Infrastructure Details
- `backend_public_ip`: Backend server public IP
- `database_endpoint`: Database connection endpoint (sensitive)
- `security_group_ids`: All security group IDs

### Deployment Information
- `deployment_instructions`: Step-by-step deployment guide
- `backend_environment_variables`: Environment variables for backend
- `estimated_monthly_cost`: Cost breakdown and estimates

## Deployment Steps

1. **Deploy Infrastructure**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

2. **Deploy Frontend**
   ```bash
   # Upload your static files to the S3 bucket
   aws s3 sync ./frontend-dist s3://your-bucket-name
   
   # Invalidate CloudFront cache (if CDN enabled)
   aws cloudfront create-invalidation --distribution-id YOUR-DIST-ID --paths "/*"
   ```

3. **Deploy Backend** (if enabled)
   ```bash
   # SSH to the EC2 instance
   ssh ec2-user@YOUR-INSTANCE-IP
   
   # Deploy your application code
   # The instance comes pre-configured with your chosen runtime
   ```

4. **Configure Database** (if enabled)
   ```bash
   # Connect to your database using the provided endpoint
   # Database credentials are available in Terraform outputs
   ```

## Cost Estimation

### AWS Free Tier Eligible
- **S3**: 5GB storage, 20,000 GET requests, 2,000 PUT requests
- **EC2**: 750 hours/month of t3.micro instance
- **RDS**: 750 hours/month of db.t3.micro instance
- **CloudFront**: 50GB data transfer, 2,000,000 requests

### Monthly Cost Estimates
- **Minimal** (Frontend only): $1-3/month
- **Basic** (Frontend + Backend): $5-10/month  
- **Full Stack** (All components): $10-25/month
- **Production** (without free tier): $25-50/month

## Security Best Practices

1. **Network Security**
   - Use specific CIDR blocks instead of 0.0.0.0/0
   - Database access only from application security group
   - HTTPS enforcement via CloudFront

2. **Access Control**
   - Implement IAM roles for EC2 instances
   - Use AWS Secrets Manager for database passwords
   - Enable deletion protection for production resources

3. **Monitoring**
   - Enable CloudWatch logs and metrics
   - Set up CloudWatch alarms for critical metrics
   - Monitor costs with AWS Cost Explorer

## Customization

The template is designed to be modular and extensible:

- **Add Custom Origins**: Extend CloudFront with additional origins
- **Multiple Environments**: Use workspaces or separate state files
- **Auto Scaling**: Add Auto Scaling Groups and Load Balancers
- **Additional Services**: Integrate with SQS, SNS, Lambda, etc.

## Troubleshooting

### Common Issues

1. **Backend not accessible**
   - Check security group rules
   - Verify instance status and logs: `sudo journalctl -u your-app-name`

2. **Database connection failures**
   - Verify security group allows access from backend
   - Check database endpoint and credentials

3. **CloudFront not serving updates**
   - Create cache invalidation: `aws cloudfront create-invalidation`
   - Check origin configuration

### Useful Commands

```bash
# Check application status
sudo systemctl status your-app-name

# View application logs  
sudo journalctl -u your-app-name -f

# Test API endpoint
curl http://localhost:8080/health

# Check nginx status
sudo systemctl status nginx
```
