# System Requirements & Setup Guide

This document outlines all system dependencies and setup steps required to run the Internal Platform Sample project successfully.

## Prerequisites

### System Dependencies

#### Required System Packages
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y redis-server python3 python3-pip python3-venv nodejs npm

# For Terraform (Ubuntu/Debian)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Alternative: Install Terraform via Snap
sudo snap install terraform

# macOS (using Homebrew)
brew install redis python3 node npm terraform

# Verify installations
terraform --version  # Should show Terraform version
redis-server --version  # Should show Redis version
python3 --version  # Should show Python 3.8+
node --version  # Should show Node.js 16+
npm --version  # Should show npm version
```

#### AWS CLI (Optional but recommended)
```bash
# Ubuntu/Debian
sudo apt install awscli

# macOS
brew install awscli

# Configure with your credentials
aws configure
```

## Project Setup

### 1. Clone and Setup
```bash
git clone <repository-url>
cd internal-platform-sample
```

### 2. Backend Setup
```bash
cd backend

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install Python dependencies
pip install -r requirements.txt
```

### 3. Frontend Setup
```bash
cd ui

# Install Node.js dependencies
npm install
```

### 4. Redis Setup
```bash
# Start Redis server
sudo systemctl start redis-server
sudo systemctl enable redis-server

# Or run Redis in Docker
docker run -d -p 6379:6379 redis:alpine

# Verify Redis is running
redis-cli ping  # Should return PONG
```

### 5. Environment Configuration
```bash
# Copy environment files
cp backend/.env.example backend/.env
cp ui/.env.example ui/.env

# Edit configuration files as needed
```

## Running the Application

### Development Mode

#### Terminal 1: Start Redis (if not running as service)
```bash
redis-server
```

#### Terminal 2: Start Backend API
```bash
cd backend
source venv/bin/activate
python3 main.py
# API will be available at http://localhost:8000
```

#### Terminal 3: Start Background Worker
```bash
cd backend
source venv/bin/activate
python3 -m application.worker
```

#### Terminal 4: Start Frontend
```bash
cd ui
npm start
# UI will be available at http://localhost:3000
```

## Infrastructure Deployment

The platform uses Terraform for infrastructure deployment. AWS credentials must be configured:

```bash
# Method 1: AWS CLI
aws configure

# Method 2: Environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# Method 3: IAM roles (recommended for EC2/ECS)
```

## Troubleshooting

### Common Issues

1. **Redis Connection Error**
   ```bash
   # Check if Redis is running
   sudo systemctl status redis-server
   # Start if stopped
   sudo systemctl start redis-server
   ```

2. **Terraform Not Found**
   ```bash
   # Install Terraform
   sudo snap install terraform
   # Or follow official installation guide
   ```

3. **Python Module Import Errors**
   ```bash
   # Ensure virtual environment is activated
   source venv/bin/activate
   # Reinstall dependencies
   pip install -r requirements.txt
   ```

4. **Node Module Errors**
   ```bash
   # Clear npm cache and reinstall
   cd ui
   rm -rf node_modules package-lock.json
   npm install
   ```

5. **Port Already in Use**
   ```bash
   # Kill process using port 8000 (backend)
   sudo kill -9 $(lsof -t -i:8000)
   # Kill process using port 3000 (frontend)
   sudo kill -9 $(lsof -t -i:3000)
   ```

## Verified Working Versions

- **Python**: 3.8+
- **Node.js**: 16+
- **Redis**: 6.0+
- **Terraform**: 1.0+
- **npm**: 8+

## Architecture Overview

The platform consists of:
- **FastAPI Backend**: REST API server
- **React Frontend**: TypeScript-based UI
- **Redis**: Queue system and caching
- **RQ Worker**: Background job processor
- **Terraform**: Infrastructure as Code
- **AWS**: Cloud infrastructure provider

## Success Indicators

After setup, you should be able to:
1. Access the UI at http://localhost:3000
2. Create infrastructure jobs through the UI
3. See jobs being processed by the worker
4. View created AWS resources in your AWS console

For additional help, refer to the individual README files in each component directory.
