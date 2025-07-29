# Sirwan Test Template

A flexible S3-focused Terraform template that demonstrates the power of modular architecture in the Internal Developer Platform. This template uses the existing `aws-s3` module to create sophisticated S3 configurations without duplicating code.

## 🎯 Purpose

This template showcases how to:
- Use existing modular infrastructure components
- Create S3 buckets with advanced configurations
- Implement cost-effective lifecycle management
- Add optional backup and logging capabilities
- Follow Infrastructure as Code best practices

## 🏗️ Architecture

```
sirwan-test/
├── main.tf           # Main template using aws-s3 module
├── variables.tf      # All configurable parameters
├── outputs.tf        # Comprehensive outputs
└── README.md         # This documentation
```

### Components Created:
- **Primary S3 Bucket**: Using the `aws-s3` module with full configuration
- **Backup S3 Bucket** (optional): Separate bucket with retention policies
- **CloudWatch Logs** (optional): For access logging and monitoring

## 🚀 Usage

### Basic S3 Bucket
```hcl
module "sirwan_test" {
  source = "./terraform/templates/sirwan-test"
  
  bucket_name = "my-test-bucket"
  environment = "dev"
}
```

### S3 Bucket with Website Hosting
```hcl
module "sirwan_test_website" {
  source = "./terraform/templates/sirwan-test"
  
  bucket_name      = "my-website"
  environment      = "prod"
  website_enabled  = true
  public_read_access = true
  
  cors_enabled = true
  cors_allowed_origins = ["https://mydomain.com"]
}
```

### S3 Bucket with Backup and Lifecycle
```hcl
module "sirwan_test_storage" {
  source = "./terraform/templates/sirwan-test"
  
  bucket_name         = "important-data"
  environment         = "prod"
  backup_enabled      = true
  lifecycle_enabled   = true
  access_logging_enabled = true
  
  lifecycle_transitions = [
    {
      days          = 30
      storage_class = "STANDARD_INFREQUENT_ACCESS"
    },
    {
      days          = 90
      storage_class = "GLACIER"
    },
    {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }
  ]
}
```

## 📋 Features

### Security Features
- ✅ Server-side encryption (AES256 or KMS)
- ✅ Bucket versioning
- ✅ Public access controls
- ✅ Force destroy protection

### Cost Optimization
- ✅ Intelligent lifecycle transitions
- ✅ Non-current version management
- ✅ Configurable retention policies
- ✅ Storage class optimization

### Website Hosting
- ✅ Static website configuration
- ✅ Custom index/error documents
- ✅ CORS configuration
- ✅ Routing rules

### Advanced Features
- ✅ Event notifications (Lambda, SNS, SQS)
- ✅ CloudWatch logging integration
- ✅ Backup bucket with retention
- ✅ Comprehensive tagging

## 💰 Cost Estimation

| Component | Estimated Monthly Cost |
|-----------|----------------------|
| S3 Standard Storage | $0.023 per GB |
| S3 IA Storage | $0.0125 per GB |
| S3 Glacier | $0.004 per GB |
| PUT Requests | $0.0005 per 1K |
| GET Requests | $0.0004 per 1K |
| Data Transfer | $0.09 per GB |
| CloudWatch Logs | $0.50 per GB |

**Total estimated range: $0.50 - $5.00/month** (depending on usage)

## 🔧 Configuration Options

### Basic Configuration
- `bucket_name`: Base name for the bucket
- `environment`: Environment tag (dev/staging/prod)
- `bucket_purpose`: Purpose description

### Security Options
- `versioning_enabled`: Enable object versioning
- `encryption_enabled`: Enable server-side encryption
- `public_read_access`: Allow public read access
- `kms_key_id`: Custom KMS key for encryption

### Website Options
- `website_enabled`: Enable static website hosting
- `website_index_document`: Index page
- `website_error_document`: Error page
- `cors_enabled`: Enable CORS configuration

### Lifecycle Options
- `lifecycle_enabled`: Enable lifecycle management
- `lifecycle_transitions`: Storage class transitions
- `lifecycle_expiration`: Object expiration rules

### Backup Options
- `backup_enabled`: Create backup bucket
- `backup_retention_days`: Backup retention period

### Monitoring Options
- `access_logging_enabled`: Enable CloudWatch logging
- `notification_enabled`: Enable S3 event notifications

## 🎨 Integration with Internal Platform

This template integrates seamlessly with the Internal Developer Platform:

### Via Backend API
```bash
curl -X POST http://localhost:8000/create-infra \
  -H "Content-Type: application/json" \
  -d '{
    "resource_type": "s3",
    "name": "sirwan-v23",
    "environment": "dev",
    "region": "us-east-1",
    "config": {
      "bucket_purpose": "test-storage",
      "versioning_enabled": true,
      "encryption_enabled": true,
      "lifecycle_enabled": true
    },
    "tags": {
      "Owner": "sirwan",
      "Template": "sirwan-test"
    }
  }'
```

### Via Terraform Directly
```bash
cd terraform/templates/sirwan-test
terraform init
terraform plan -var="bucket_name=sirwan-v23"
terraform apply -var="bucket_name=sirwan-v23"
```

## 📊 Outputs

The template provides comprehensive outputs:
- **bucket_info**: Basic bucket information
- **security**: Security configuration details
- **website**: Website hosting details (if enabled)
- **endpoints**: All access endpoints
- **usage_examples**: AWS CLI usage examples
- **backup_bucket**: Backup configuration (if enabled)
- **logging**: CloudWatch logging details (if enabled)
- **quick_start_guide**: Step-by-step usage guide

## 🔍 Example Output

```json
{
  "bucket_info": {
    "bucket_name": "sirwan-v23-a1b2c3d4",
    "bucket_arn": "arn:aws:s3:::sirwan-v23-a1b2c3d4",
    "region": "us-east-1"
  },
  "quick_start_guide": {
    "steps": [
      "1. Your S3 bucket 'sirwan-v23-a1b2c3d4' is now ready",
      "2. Upload files: aws s3 cp ./file.txt s3://sirwan-v23-a1b2c3d4/",
      "3. List contents: aws s3 ls s3://sirwan-v23-a1b2c3d4/"
    ]
  }
}
```

## 🏆 Benefits of This Modular Approach

1. **Reusability**: Uses existing `aws-s3` module
2. **Consistency**: Same security and tagging standards
3. **Maintainability**: Single source of truth for S3 logic
4. **Flexibility**: Extensive configuration options
5. **Cost Efficiency**: Built-in lifecycle management
6. **Documentation**: Comprehensive outputs and examples

## 🔄 Integration with Job System

The template works with the existing job processing system:
- Template files are copied to job workspace
- Variables are generated from job configuration
- Terraform execution follows standard workflow
- Outputs are captured and returned to API

This demonstrates the power of modular architecture - creating new capabilities without changing existing code!
