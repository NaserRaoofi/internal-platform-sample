#!/bin/bash
# Basic EC2 setup for Sirwan Test Template with S3 integration

# Update system
yum update -y

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws/

# Install useful tools
yum install -y htop tree git nano curl wget

# Set environment variables
cat >> /etc/environment << EOF
AWS_DEFAULT_REGION=${region}
S3_BUCKET_NAME=${bucket_name}
S3_BUCKET_ARN=${bucket_arn}
ENVIRONMENT=${environment}
EOF

# Create data directory
mkdir -p /opt/s3-data
chown ec2-user:ec2-user /opt/s3-data

# Create welcome message
cat > /home/ec2-user/welcome.txt << EOF
========================================
🚀 Sirwan Test Template - EC2 + S3
========================================

S3 Bucket: ${bucket_name}
Environment: ${environment}
Region: ${region}

Quick S3 Commands:
  aws s3 ls s3://${bucket_name}/
  aws s3 cp file.txt s3://${bucket_name}/
  aws s3 sync /opt/s3-data s3://${bucket_name}/

Data Directory: /opt/s3-data
========================================
EOF

chown ec2-user:ec2-user /home/ec2-user/welcome.txt

# Add welcome message to login
echo "cat /home/ec2-user/welcome.txt" >> /home/ec2-user/.bashrc

# Create test file
echo "Hello from EC2 instance! Created at $(date)" > /opt/s3-data/test.txt
echo "Bucket: ${bucket_name}" >> /opt/s3-data/test.txt
echo "Environment: ${environment}" >> /opt/s3-data/test.txt

# Upload test file to S3 (if bucket is accessible)
aws s3 cp /opt/s3-data/test.txt s3://${bucket_name}/test.txt 2>/dev/null || echo "S3 upload will be available after IAM role is attached"

echo "EC2 setup completed!" > /var/log/user-data.log
