#!/bin/bash
# Script to start backend with real Terraform deployment enabled

# Stop any running backend
pkill -f "uvicorn main:app" 2>/dev/null || true

# Set up environment for real deployment
export ENABLE_REAL_TERRAFORM=true
export TERRAFORM_WORKSPACE_DIR=/tmp/terraform-workspaces
export AWS_REGION=us-east-1

# Check prerequisites
echo "🔍 Checking prerequisites..."

# Check Terraform
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not found. Please install Terraform first."
    exit 1
fi

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install AWS CLI first."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Please run 'aws configure' first."
    echo "ℹ️  For testing, you can use AWS CLI with appropriate credentials"
    echo "ℹ️  Or set environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY"
    exit 1
fi

echo "✅ All prerequisites met!"
echo "🚀 Starting backend with REAL Terraform deployment..."

# Start backend with real Terraform enabled
cd /home/sirwan/IDP/internal-platform-sample/backend
poetry run uvicorn main:app --reload --host 0.0.0.0 --port 8001
