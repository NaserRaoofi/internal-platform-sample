#!/bin/bash
# S3 Integration Script for Sirwan Test Template
# This script configures the EC2 instance to work with the S3 bucket

# Update system
yum update -y

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install additional tools
yum install -y htop tree git nano

# Set environment variables
cat >> /etc/environment << EOF
AWS_DEFAULT_REGION=${region}
S3_BUCKET_NAME=${bucket_name}
S3_BUCKET_ARN=${bucket_arn}
ENVIRONMENT=${environment}
EOF

# Create S3 integration script
cat > /usr/local/bin/s3-sync << 'EOF'
#!/bin/bash
# S3 Sync utility script

BUCKET_NAME="${bucket_name}"
LOCAL_DIR="/opt/s3-data"

# Create local directory if it doesn't exist
mkdir -p "$LOCAL_DIR"

case "$1" in
    "upload")
        echo "Uploading $LOCAL_DIR to s3://$BUCKET_NAME/"
        aws s3 sync "$LOCAL_DIR" "s3://$BUCKET_NAME/"
        ;;
    "download")
        echo "Downloading s3://$BUCKET_NAME/ to $LOCAL_DIR"
        aws s3 sync "s3://$BUCKET_NAME/" "$LOCAL_DIR"
        ;;
    "list")
        echo "Listing contents of s3://$BUCKET_NAME/"
        aws s3 ls "s3://$BUCKET_NAME/" --recursive
        ;;
    "info")
        echo "S3 Bucket Information:"
        echo "  Bucket Name: $BUCKET_NAME"
        echo "  Bucket ARN: ${bucket_arn}"
        echo "  Region: ${region}"
        echo "  Local Directory: $LOCAL_DIR"
        echo ""
        echo "Usage:"
        echo "  s3-sync upload    - Upload local files to S3"
        echo "  s3-sync download  - Download S3 files locally"
        echo "  s3-sync list      - List S3 bucket contents"
        echo "  s3-sync info      - Show this information"
        ;;
    *)
        echo "Usage: s3-sync {upload|download|list|info}"
        echo "Run 's3-sync info' for more details"
        exit 1
        ;;
esac
EOF

# Make the script executable
chmod +x /usr/local/bin/s3-sync

# Create data directory with proper permissions
mkdir -p /opt/s3-data
chown ec2-user:ec2-user /opt/s3-data

# Create welcome script
cat > /home/ec2-user/welcome.sh << EOF
#!/bin/bash
echo "=========================================="
echo "🚀 Sirwan Test Template - EC2 + S3"
echo "=========================================="
echo ""
echo "S3 Bucket: ${bucket_name}"
echo "Environment: ${environment}"
echo "Region: ${region}"
echo ""
echo "Quick Commands:"
echo "  s3-sync info      - Show S3 information"
echo "  s3-sync list      - List bucket contents"
echo "  s3-sync download  - Download files from S3"
echo "  s3-sync upload    - Upload files to S3"
echo ""
echo "Data Directory: /opt/s3-data"
echo "=========================================="
EOF

chmod +x /home/ec2-user/welcome.sh
chown ec2-user:ec2-user /home/ec2-user/welcome.sh

# Add welcome script to .bashrc
echo "" >> /home/ec2-user/.bashrc
echo "# Sirwan Test Template Welcome" >> /home/ec2-user/.bashrc
echo "/home/ec2-user/welcome.sh" >> /home/ec2-user/.bashrc

# Test S3 connection
echo "Testing S3 connection..." > /var/log/s3-setup.log
aws s3 ls s3://${bucket_name} >> /var/log/s3-setup.log 2>&1

# Create a test file
echo "Hello from EC2 instance! Created at $(date)" > /opt/s3-data/ec2-test.txt
echo "Bucket: ${bucket_name}" >> /opt/s3-data/ec2-test.txt
echo "Environment: ${environment}" >> /opt/s3-data/ec2-test.txt

# Upload test file to S3
aws s3 cp /opt/s3-data/ec2-test.txt s3://${bucket_name}/ec2-test.txt

echo "EC2 S3 integration setup completed!" >> /var/log/s3-setup.log
