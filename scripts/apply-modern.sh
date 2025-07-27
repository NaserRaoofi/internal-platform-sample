#!/bin/bash

# Modern Terraform Apply Script - Production Ready
# This script processes provisioning requests using Terraform modules and environments

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_ENV_DIR="$PROJECT_ROOT/terraform/environments/dev"
QUEUE_DIR="$PROJECT_ROOT/queue"
PROCESSING_DIR="$QUEUE_DIR/processing"
COMPLETED_DIR="$QUEUE_DIR/completed"
FAILED_DIR="$QUEUE_DIR/failed"

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Initialize directories
init_directories() {
    log "Initializing directories..."
    mkdir -p "$QUEUE_DIR" "$PROCESSING_DIR" "$COMPLETED_DIR" "$FAILED_DIR"
    mkdir -p "$TERRAFORM_ENV_DIR"
}

# Check if Terraform is installed
check_terraform() {
    if ! command -v terraform &> /dev/null; then
        error_exit "Terraform is not installed. Please install Terraform first."
    fi
    log "Terraform version: $(terraform version -json | jq -r '.terraform_version' 2>/dev/null || terraform version)"
}

# Check if AWS CLI is configured
check_aws() {
    if ! command -v aws &> /dev/null; then
        log "WARNING: AWS CLI not found. Using default provider configuration."
    else
        log "AWS CLI version: $(aws --version 2>/dev/null || echo 'Unable to get version')"
        if ! aws sts get-caller-identity &>/dev/null; then
            log "WARNING: AWS credentials not configured. Resources will fail to create."
        fi
    fi
}

# Process pending requests into Terraform variables
process_requests() {
    log "Processing pending requests..."
    
    local requests_json="{}"
    local processed_count=0
    
    # Find all pending request files
    for request_file in "$QUEUE_DIR/pending"/*.json; do
        [[ -f "$request_file" ]] || continue
        
        local filename=$(basename "$request_file")
        local request_id="${filename%.json}"
        
        log "Processing request: $request_id"
        
        # Move to processing
        mv "$request_file" "$PROCESSING_DIR/"
        
        # Update status to in_progress
        update_request_status "$request_id" "in_progress" ""
        
        # Read request and add to Terraform variables
        local request_content=$(cat "$PROCESSING_DIR/$filename")
        
        # Add to requests JSON using jq
        requests_json=$(echo "$requests_json" | jq --arg id "$request_id" --argjson request "$request_content" \
            '.[$id] = {
                resource_type: $request.resource_type,
                resource_config: $request.resource_config,
                requester: $request.requester
            }')
        
        ((processed_count++))
    done
    
    if [[ $processed_count -eq 0 ]]; then
        log "No pending requests found."
        return 0
    fi
    
    log "Found $processed_count request(s) to process"
    
    # Create Terraform variables file
    local tfvars_file="$TERRAFORM_ENV_DIR/terraform.tfvars.json"
    echo "$requests_json" | jq '{instance_requests: .}' > "$tfvars_file"
    
    log "Created Terraform variables file: $tfvars_file"
    return $processed_count
}

# Apply Terraform configuration
apply_terraform() {
    log "Applying Terraform configuration..."
    
    cd "$TERRAFORM_ENV_DIR"
    
    # Initialize Terraform
    log "Initializing Terraform..."
    if ! terraform init -no-color; then
        error_exit "Terraform initialization failed"
    fi
    
    # Validate configuration
    log "Validating Terraform configuration..."
    if ! terraform validate -no-color; then
        error_exit "Terraform validation failed"
    fi
    
    # Plan the changes
    log "Planning Terraform changes..."
    if ! terraform plan -no-color -var-file=terraform.tfvars.json -out=tfplan; then
        error_exit "Terraform plan failed"
    fi
    
    # Apply the changes
    log "Applying Terraform changes..."
    if ! terraform apply -no-color -auto-approve tfplan; then
        error_exit "Terraform apply failed"
    fi
    
    # Get outputs
    log "Getting Terraform outputs..."
    terraform output -json > terraform-outputs.json 2>/dev/null || echo "{}" > terraform-outputs.json
    
    log "Terraform apply completed successfully"
}

# Update request status in the API
update_request_status() {
    local request_id="$1"
    local status="$2"
    local error_message="$3"
    
    # Use Python to make the API call
    python3 -c "
import requests
import json
from datetime import datetime

try:
    data = {
        'status': '$status',
        'updated_at': datetime.utcnow().isoformat(),
    }
    if '$error_message':
        data['error_message'] = '$error_message'
    
    response = requests.patch(
        'http://localhost:8000/requests/$request_id/status',
        json=data,
        timeout=10
    )
    if response.status_code == 200:
        print('Updated status for request $request_id to $status')
    else:
        print(f'Failed to update status: {response.status_code}')
except Exception as e:
    print(f'Error updating status: {e}')
"
}

# Process results and update request statuses
process_results() {
    log "Processing results..."
    
    local outputs_file="$TERRAFORM_ENV_DIR/terraform-outputs.json"
    
    # Process each request in the processing directory
    for request_file in "$PROCESSING_DIR"/*.json; do
        [[ -f "$request_file" ]] || continue
        
        local filename=$(basename "$request_file")
        local request_id="${filename%.json}"
        
        log "Processing results for request: $request_id"
        
        # Check if the request was successful by looking at outputs
        local success=true
        local error_message=""
        
        # For now, assume success if we got this far
        # In a real implementation, you'd parse the Terraform outputs to check for specific resources
        
        if [[ "$success" == "true" ]]; then
            log "Request $request_id completed successfully"
            update_request_status "$request_id" "completed" ""
            mv "$request_file" "$COMPLETED_DIR/"
        else
            log "Request $request_id failed: $error_message"
            update_request_status "$request_id" "failed" "$error_message"
            mv "$request_file" "$FAILED_DIR/"
        fi
    done
}

# Handle errors and move failed requests
handle_failure() {
    log "Handling failure, moving requests to failed directory..."
    
    for request_file in "$PROCESSING_DIR"/*.json; do
        [[ -f "$request_file" ]] || continue
        
        local filename=$(basename "$request_file")
        local request_id="${filename%.json}"
        
        log "Marking request $request_id as failed"
        update_request_status "$request_id" "failed" "Terraform apply failed"
        mv "$request_file" "$FAILED_DIR/"
    done
}

# Cleanup function
cleanup() {
    log "Cleaning up..."
    cd "$PROJECT_ROOT"
    
    # Remove tfplan file
    rm -f "$TERRAFORM_ENV_DIR/tfplan"
    
    # Keep terraform.tfvars.json for debugging, but could be removed in production
    # rm -f "$TERRAFORM_ENV_DIR/terraform.tfvars.json"
}

# Main execution
main() {
    log "Starting Modern Terraform Apply Script"
    
    # Trap to handle cleanup on exit
    trap cleanup EXIT
    trap handle_failure ERR
    
    init_directories
    check_terraform
    check_aws
    
    # Process requests
    if ! process_requests; then
        log "No requests to process, exiting"
        exit 0
    fi
    
    # Apply Terraform
    apply_terraform
    
    # Process results
    process_results
    
    log "Script execution completed successfully"
}

# Run main function
main "$@"
