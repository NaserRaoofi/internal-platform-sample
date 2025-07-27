#!/bin/bash

# Development Setup Script
# This script sets up the development environment for the Internal Developer Platform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[SETUP]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install Poetry if not present
setup_poetry() {
    if command_exists poetry; then
        log "Poetry is already installed"
    else
        log "Installing Poetry..."
        curl -sSL https://install.python-poetry.org | python3 -
        export PATH="$HOME/.local/bin:$PATH"
    fi
}

# Setup Python environment
setup_python() {
    log "Setting up Python environment..."
    
    if [[ ! -f "pyproject.toml" ]]; then
        error "pyproject.toml not found"
        exit 1
    fi
    
    # Install dependencies
    poetry install
    
    success "Python environment setup complete"
}

# Create necessary directories
create_directories() {
    log "Creating project directories..."
    
    local dirs=(
        "queue/pending"
        "queue/processing" 
        "queue/completed"
        "storage"
        "terraform/ec2/instances"
        "terraform/vpc/instances"
        "terraform/s3/instances"
        "logs"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        log "Created directory: $dir"
    done
    
    success "Directories created"
}

# Setup git hooks (optional)
setup_git_hooks() {
    if [[ -d ".git" ]]; then
        log "Setting up git hooks..."
        
        # Create pre-commit hook for code formatting
        cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Pre-commit hook for code formatting

# Check if poetry is available
if command -v poetry >/dev/null 2>&1; then
    echo "Running code formatters..."
    
    # Format Python code
    poetry run black backend/ ui/ --check --quiet || {
        echo "Code formatting required. Run: poetry run black backend/ ui/"
        exit 1
    }
    
    # Sort imports
    poetry run isort backend/ ui/ --check-only --quiet || {
        echo "Import sorting required. Run: poetry run isort backend/ ui/"
        exit 1
    }
fi
EOF
        chmod +x .git/hooks/pre-commit
        success "Git hooks setup complete"
    else
        warning "Not a git repository, skipping git hooks setup"
    fi
}

# Create configuration files
create_config() {
    log "Creating configuration files..."
    
    # Create .env file template
    if [[ ! -f ".env" ]]; then
        cat > .env << 'EOF'
# Internal Developer Platform Configuration

# API Configuration
API_HOST=0.0.0.0
API_PORT=8000

# UI Configuration  
UI_PORT=8080

# AWS Configuration
AWS_REGION=us-west-2
AWS_PROFILE=default

# Queue Configuration
QUEUE_DIR=queue
STORAGE_DIR=storage
TERRAFORM_DIR=terraform

# Processing Configuration
WATCH_INTERVAL=10
EOF
        log "Created .env configuration file"
    fi
    
    # Create .gitignore
    if [[ ! -f ".gitignore" ]]; then
        cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
ENV/
env.bak/
venv.bak/

# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
terraform.tfplan
terraform.tfvars.backup
*.tfvars
!terraform.tfvars.example

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Logs
logs/
*.log

# Environment
.env
.env.local

# Queue and Storage (optional - remove if you want to track requests)
queue/pending/*
queue/processing/*
queue/completed/*
storage/*

# Terraform instances
terraform/*/instances/*
EOF
        log "Created .gitignore file"
    fi
}

# Run tests
run_tests() {
    log "Running tests..."
    
    # Create basic test file if it doesn't exist
    if [[ ! -f "tests/test_basic.py" ]]; then
        mkdir -p tests
        cat > tests/test_basic.py << 'EOF'
"""Basic tests for the Internal Developer Platform."""

import pytest
from backend.domain.models import EC2Request, VPCRequest, S3Request, ProvisioningRequest, ResourceType


def test_ec2_request_creation():
    """Test EC2 request model creation."""
    ec2_request = EC2Request(
        instance_type="t3.micro",
        ami_id="ami-12345",
        key_pair_name="test-key"
    )
    assert ec2_request.instance_type == "t3.micro"
    assert ec2_request.ami_id == "ami-12345"


def test_vpc_request_creation():
    """Test VPC request model creation."""
    vpc_request = VPCRequest(
        cidr_block="10.0.0.0/16",
        availability_zones=["us-west-2a", "us-west-2b"],
        public_subnet_cidrs=["10.0.1.0/24", "10.0.2.0/24"],
        private_subnet_cidrs=["10.0.10.0/24", "10.0.20.0/24"]
    )
    assert vpc_request.cidr_block == "10.0.0.0/16"
    assert len(vpc_request.availability_zones) == 2


def test_s3_request_creation():
    """Test S3 request model creation."""
    s3_request = S3Request(
        bucket_name="test-bucket"
    )
    assert s3_request.bucket_name == "test-bucket"
    assert s3_request.encryption_enabled is True


def test_provisioning_request_creation():
    """Test provisioning request model creation."""
    request = ProvisioningRequest(
        id="test-123",
        requester="test-user",
        resource_type=ResourceType.EC2,
        resource_config={"instance_type": "t3.micro"}
    )
    assert request.id == "test-123"
    assert request.resource_type == ResourceType.EC2
    assert request.status.value == "pending"
EOF
        log "Created basic test file"
    fi
    
    # Run pytest if available
    if poetry run python -c "import pytest" 2>/dev/null; then
        poetry run pytest tests/ -v
        success "Tests completed"
    else
        warning "pytest not available, skipping tests"
    fi
}

# Check system requirements
check_requirements() {
    log "Checking system requirements..."
    
    local missing_deps=()
    
    # Check Python
    if ! command_exists python3; then
        missing_deps+=("python3")
    fi
    
    # Check curl (for Poetry installation)
    if ! command_exists curl; then
        missing_deps+=("curl")
    fi
    
    # Check git (optional)
    if ! command_exists git; then
        warning "Git not found - version control features will be limited"
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing required dependencies: ${missing_deps[*]}"
        echo "Please install them and run this script again."
        exit 1
    fi
    
    success "System requirements check passed"
}

# Display usage information
show_usage() {
    cat << EOF

🚀 Internal Developer Platform Setup Complete!

Next steps:

1. Start the backend API:
   cd backend && poetry run uvicorn main:app --reload

2. Start the UI (in another terminal):
   cd ui && poetry run python app.py

3. Process requests automatically:
   ./scripts/watch.sh

4. Or process requests manually:
   ./scripts/apply.sh

Configuration:
- Edit .env file for custom settings
- Backend API: http://localhost:8000
- Frontend UI: http://localhost:8080
- API Documentation: http://localhost:8000/docs

For development:
- Format code: poetry run black backend/ ui/
- Sort imports: poetry run isort backend/ ui/
- Run tests: poetry run pytest

EOF
}

# Main setup function
main() {
    log "Starting Internal Developer Platform setup..."
    
    check_requirements
    setup_poetry
    setup_python
    create_directories
    create_config
    setup_git_hooks
    run_tests
    
    success "Setup completed successfully!"
    show_usage
}

# Run main function
main "$@"
