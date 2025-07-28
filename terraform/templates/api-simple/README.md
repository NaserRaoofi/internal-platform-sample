# API Simple Module

A complete, self-contained Terraform module for deploying simple API services on AWS. This module is optimized for AWS Free Tier usage and supports multiple programming languages.

## Features

- **Multi-language Support**: Node.js, Python, Java, Go
- **AWS Free Tier Optimized**: Costs $0-5/month
- **Optional Database**: PostgreSQL or MySQL with RDS
- **Security**: Configurable security groups, encrypted storage
- **Monitoring**: CloudWatch integration
- **Auto-scaling Ready**: Can be extended with load balancers
- **Production Ready**: SSL, backups, monitoring

## Supported Runtimes

| Runtime | Version | Package Manager | Framework Examples |
|---------|---------|-----------------|-------------------|
| Node.js | 18.x    | npm            | Express, Fastify, Koa |
| Python  | 3.9+    | pip            | FastAPI, Flask, Django |
| Java    | 11      | Maven          | Spring Boot, Quarkus |
| Go      | 1.21    | go modules     | Gin, Echo, Standard lib |

## Quick Start

```hcl
module "my_api" {
  source = "./modules/api-simple"
  
  api_name     = "my-awesome-api"
  runtime      = "nodejs"
  environment  = "dev"
  
  # Optional database
  database_required = true
  database_type    = "postgres"
  
  # Security
  allowed_ips = ["0.0.0.0/0"]  # Restrict in production
  
  tags = {
    Project = "MyProject"
    Owner   = "DevTeam"
  }
}
```

## Input Variables

### Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `api_name` | string | Name of the API service (3-50 chars, alphanumeric and hyphens) |

### Optional Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `runtime` | string | `"nodejs"` | Programming language (nodejs, python, java, go) |
| `environment` | string | `"dev"` | Environment (dev, staging, prod) |
| `instance_type` | string | `"t2.micro"` | EC2 instance type |
| `database_required` | bool | `false` | Whether to provision a database |
| `database_type` | string | `"postgres"` | Database engine (postgres, mysql) |
| `api_port` | number | `3000` | Port for the API service |
| `monitoring_enabled` | bool | `true` | Enable CloudWatch monitoring |
| `ssl_enabled` | bool | `false` | Enable SSL/TLS |
| `allowed_ips` | list(string) | `["0.0.0.0/0"]` | Allowed IP addresses |

For a complete list of variables, see [variables.tf](./variables.tf).

## Outputs

### Key Outputs

- `api_info`: Complete API service information
- `endpoints`: All API endpoints and URLs
- `database`: Database connection details (if enabled)
- `cost_estimate`: Monthly cost breakdown
- `quick_start_guide`: Step-by-step usage guide

### Example Output

```hcl
api_info = {
  api_id = "my-api-a1b2c3d4"
  api_name = "my-api"
  environment = "dev"
  runtime = "nodejs"
  status = "deployed"
}

endpoints = {
  api_url = "http://52.12.34.56:3000"
  health_check = "http://52.12.34.56:3000/health"
  ssh_access = "ssh ec2-user@52.12.34.56"
}

cost_estimate = {
  total_estimated = 0
  free_tier_eligible = true
}
```

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Internet      │    │   EC2 Instance  │    │   RDS Database  │
│   Gateway       │───▶│   (API Server)  │───▶│   (Optional)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                       ┌─────────────────┐
                       │   CloudWatch    │
                       │   (Monitoring)  │
                       └─────────────────┘
```

## Security Features

- **Encrypted Storage**: All EBS volumes encrypted at rest
- **Security Groups**: Minimal required ports only
- **IAM Roles**: Least privilege access
- **VPC**: Databases in private subnets
- **IMDSv2**: Instance metadata service v2 enforced

## Cost Breakdown

### Free Tier Eligible (t2.micro + no database)
- EC2 Instance: $0/month (750 hours free)
- Storage: $2/month (20GB)
- Data Transfer: $0/month (1GB free)
- **Total: ~$2/month**

### With Database (t3.micro + RDS t3.micro)
- EC2 Instance: $7.59/month
- RDS Database: $12.00/month
- Storage: $3/month
- **Total: ~$22/month**

## Application Structure

The module automatically creates a basic application structure:

### Node.js
```
/opt/my-api/
├── package.json
├── index.js
├── .env
└── node_modules/
```

### Python
```
/opt/my-api/
├── main.py
├── requirements.txt
└── __pycache__/
```

### Java
```
/opt/my-api/
├── pom.xml
├── src/main/java/
└── target/
```

### Go
```
/opt/my-api/
├── main.go
├── go.mod
└── my-api (binary)
```

## Health Monitoring

All deployments include:
- Health check endpoint at `/health`
- Systemd service management
- Basic monitoring script
- CloudWatch integration (if enabled)
- Nginx reverse proxy

## Database Connection

If database is enabled, connection details are available via:

```bash
# Environment variables are set in the application
DATABASE_HOST=your-db-endpoint
DATABASE_PORT=5432
DATABASE_NAME=your_api_name
DATABASE_USER=apiuser
DATABASE_PASSWORD=generated-password
```

## Customization

### Custom User Data

To customize the server setup, modify the `user_data.sh` script:

```hcl
module "my_api" {
  source = "./modules/api-simple"
  
  api_name = "my-api"
  
  # Override user data
  user_data = base64encode(templatefile("./custom-setup.sh", {
    api_name = "my-api"
    runtime  = "nodejs"
  }))
}
```

### Custom Security Groups

```hcl
module "my_api" {
  source = "./modules/api-simple"
  
  api_name    = "my-api"
  allowed_ips = ["10.0.0.0/8", "192.168.1.0/24"]  # Restrict access
}
```

## Troubleshooting

### Check Service Status
```bash
ssh ec2-user@YOUR_IP
sudo systemctl status your-api-name
```

### View Application Logs
```bash
sudo journalctl -f -u your-api-name
```

### Test Health Endpoint
```bash
curl http://YOUR_IP:3000/health
```

### Database Connection Test
```bash
# For PostgreSQL
psql -h YOUR_DB_ENDPOINT -U apiuser -d your_db_name

# For MySQL
mysql -h YOUR_DB_ENDPOINT -u apiuser -p your_db_name
```

## Examples

### Simple Node.js API
```hcl
module "simple_nodejs_api" {
  source = "./modules/api-simple"
  
  api_name = "user-service"
  runtime  = "nodejs"
  api_port = 3000
}
```

### Python API with Database
```hcl
module "python_api_with_db" {
  source = "./modules/api-simple"
  
  api_name          = "product-api"
  runtime           = "python"
  database_required = true
  database_type     = "postgres"
  backup_enabled    = true
}
```

### Production Java API
```hcl
module "production_java_api" {
  source = "./modules/api-simple"
  
  api_name         = "order-service"
  runtime          = "java"
  environment      = "prod"
  instance_type    = "t3.small"
  ssl_enabled      = true
  delete_protection = true
  
  allowed_ips = ["10.0.0.0/8"]  # Internal network only
}
```

## Best Practices

1. **Use specific allowed_ips**: Don't use `0.0.0.0/0` in production
2. **Enable SSL**: Set `ssl_enabled = true` and configure domain
3. **Monitor costs**: Check the cost_estimate output
4. **Use tags**: Add meaningful tags for resource management
5. **Backup important data**: Enable `backup_enabled` for production
6. **Test health endpoint**: Always implement `/health` endpoint

## Contributing

This module is part of the Internal Developer Platform. To contribute:

1. Test changes locally
2. Update documentation
3. Follow Terraform best practices
4. Ensure AWS Free Tier compatibility

## Support

For issues and questions:
- Check the troubleshooting section
- Review CloudWatch logs
- Test with minimal configuration first
