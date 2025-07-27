#!/bin/bash

# Terraform Apply Script for Internal Developer Platform
# This script processes the request queue and applies Terraform configurations

set -e  # Exit on any error

# Configuration
QUEUE_DIR="${QUEUE_DIR:-queue}"
PENDING_DIR="$QUEUE_DIR/pending"
PROCESSING_DIR="$QUEUE_DIR/processing"
COMPLETED_DIR="$QUEUE_DIR/completed"
TERRAFORM_DIR="${TERRAFORM_DIR:-terraform}"
STORAGE_DIR="${STORAGE_DIR:-storage}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Create necessary directories
create_directories() {
    log "Creating necessary directories..."
    mkdir -p "$PENDING_DIR" "$PROCESSING_DIR" "$COMPLETED_DIR" "$STORAGE_DIR"
    
    for resource in ec2 vpc s3; do
        mkdir -p "$TERRAFORM_DIR/$resource/instances"
    done
}

# Update request status in storage
update_request_status() {
    local request_id="$1"
    local status="$2"
    local error_message="$3"
    local terraform_output="$4"
    
    local storage_file="$STORAGE_DIR/$request_id.json"
    
    if [[ -f "$storage_file" ]]; then
        # Use Python to update the JSON file
        python3 -c "
import json
import sys
from datetime import datetime

request_id = '$request_id'
status = '$status'
error_message = '$error_message'
terraform_output = '$terraform_output'

try:
    with open('$storage_file', 'r') as f:
        data = json.load(f)
    
    data['status'] = status
    data['updated_at'] = datetime.utcnow().isoformat()
    
    if error_message:
        data['error_message'] = error_message
    
    if terraform_output:
        try:
            data['terraform_output'] = json.loads(terraform_output)
        except json.JSONDecodeError:
            data['terraform_output'] = {'raw_output': terraform_output}
    
    with open('$storage_file', 'w') as f:
        json.dump(data, f, indent=2)
        
    print(f'Updated status for request {request_id} to {status}')
except Exception as e:
    print(f'Failed to update status: {e}', file=sys.stderr)
    sys.exit(1)
"
    else
        error "Storage file not found for request $request_id"
        return 1
    fi
}

# Generate Terraform configuration from request
generate_terraform_config() {
    local request_file="$1"
    local request_id="$2"
    
    log "Generating Terraform configuration for request $request_id"
    
    # Extract request details using Python
    python3 -c "
import json
import os

with open('$request_file', 'r') as f:
    request = json.load(f)

resource_type = request['resource_type']
resource_config = request['resource_config']
request_id = request['id']

# Create instance directory
instance_dir = f'$TERRAFORM_DIR/{resource_type}/instances/{request_id}'
os.makedirs(instance_dir, exist_ok=True)

# Generate main.tf
main_tf_content = f'''
# Generated Terraform configuration for request {request_id}
# Resource type: {resource_type}

terraform {{
  required_version = \">= 1.0\"
  required_providers {{
    aws = {{
      source  = \"hashicorp/aws\"
      version = \"~> 5.0\"
    }}
  }}
}}

# Configure AWS Provider
provider \"aws\" {{
  region = var.aws_region
}}

# Use the {resource_type} module
module \"{resource_type}_instance\" {{
  source = \"../../{resource_type}\"
'''

# Add variables based on resource config
for key, value in resource_config.items():
    if isinstance(value, str):
        main_tf_content += f'  {key} = \"{value}\"\\n'
    elif isinstance(value, bool):
        main_tf_content += f'  {key} = {str(value).lower()}\\n'
    elif isinstance(value, list):
        if all(isinstance(item, str) for item in value):
            formatted_list = ', '.join([f'\\\"{item}\\\"' for item in value])
            main_tf_content += f'  {key} = [{formatted_list}]\\n'
        else:
            main_tf_content += f'  {key} = {json.dumps(value)}\\n'
    elif isinstance(value, dict):
        main_tf_content += f'  {key} = {json.dumps(value)}\\n'
    else:
        main_tf_content += f'  {key} = {json.dumps(value)}\\n'

main_tf_content += '''
}

# Output all module outputs
output \"resource_outputs\" {
  description = \"All outputs from the resource module\"
  value       = module.''' + resource_type + '''_instance
}
'''

# Write main.tf
with open(f'{instance_dir}/main.tf', 'w') as f:
    f.write(main_tf_content)

# Generate variables.tf
variables_tf_content = '''
variable \"aws_region\" {
  description = \"AWS region\"
  type        = string
  default     = \"us-west-2\"
}
'''

with open(f'{instance_dir}/variables.tf', 'w') as f:
    f.write(variables_tf_content)

# Generate terraform.tfvars
tfvars_content = '''
aws_region = \"us-west-2\"
'''

with open(f'{instance_dir}/terraform.tfvars', 'w') as f:
    f.write(tfvars_content)

print(f'{instance_dir}')
"
}

# Apply Terraform configuration
apply_terraform() {
    local terraform_dir="$1"
    local request_id="$2"
    
    log "Applying Terraform configuration in $terraform_dir"
    
    cd "$terraform_dir"
    
    # Initialize Terraform
    if ! terraform init -no-color; then
        error "Terraform init failed"
        return 1
    fi
    
    # Plan Terraform
    if ! terraform plan -no-color -out=tfplan; then
        error "Terraform plan failed"
        return 1
    fi
    
    # Apply Terraform
    if ! terraform apply -no-color -auto-approve tfplan; then
        error "Terraform apply failed"
        return 1
    fi
    
    # Get outputs
    terraform output -json > outputs.json
    
    cd - > /dev/null
    
    return 0
}

# Process a single request
process_request() {
    local request_file="$1"
    local request_id
    request_id=$(basename "$request_file" .json)
    
    log "Processing request: $request_id"
    
    # Update status to in_progress
    update_request_status "$request_id" "in_progress" "" ""
    
    # Generate Terraform configuration
    terraform_instance_dir=$(generate_terraform_config "$request_file" "$request_id")
    
    if [[ -z "$terraform_instance_dir" ]]; then
        error "Failed to generate Terraform configuration"
        update_request_status "$request_id" "failed" "Failed to generate Terraform configuration" ""
        return 1
    fi
    
    # Apply Terraform
    if apply_terraform "$terraform_instance_dir" "$request_id"; then
        # Read outputs
        local outputs=""
        if [[ -f "$terraform_instance_dir/outputs.json" ]]; then
            outputs=$(cat "$terraform_instance_dir/outputs.json")
        fi
        
        # Update status to completed
        update_request_status "$request_id" "completed" "" "$outputs"
        
        # Move request to completed
        mv "$request_file" "$COMPLETED_DIR/"
        
        success "Successfully processed request $request_id"
        return 0
    else
        # Get error details
        local error_log=""
        if [[ -f "$terraform_instance_dir/terraform.log" ]]; then
            error_log=$(tail -n 50 "$terraform_instance_dir/terraform.log")
        fi
        
        # Update status to failed
        update_request_status "$request_id" "failed" "Terraform apply failed" "$error_log"
        
        error "Failed to process request $request_id"
        return 1
    fi
}

# Main processing loop
process_queue() {
    log "Starting queue processing..."
    
    # Process all pending requests
    for request_file in "$PENDING_DIR"/*.json; do
        # Check if there are actually any files
        if [[ ! -f "$request_file" ]]; then
            log "No pending requests found"
            break
        fi
        
        # Move to processing directory
        processing_file="$PROCESSING_DIR/$(basename "$request_file")"
        mv "$request_file" "$processing_file"
        
        # Process the request
        if ! process_request "$processing_file"; then
            warning "Request processing failed, moving to completed directory"
            mv "$processing_file" "$COMPLETED_DIR/"
        fi
    done
    
    success "Queue processing completed"
}

# Main script execution
main() {
    log "Starting Terraform Apply Script"
    
    # Check dependencies
    if ! command -v terraform &> /dev/null; then
        error "Terraform is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v python3 &> /dev/null; then
        error "Python 3 is not installed or not in PATH"
        exit 1
    fi
    
    # Create directories
    create_directories
    
    # Process the queue
    process_queue
    
    log "Script execution completed"
}

# Run main function
main "$@"
