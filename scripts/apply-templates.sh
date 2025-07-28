#!/bin/bash

# Template-based Terraform Apply Script
# This script processes provisioning requests using application templates

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_TEMPLATES_DIR="$PROJECT_ROOT/terraform/templates"
QUEUE_DIR="$PROJECT_ROOT/queue"
PROCESSING_DIR="$QUEUE_DIR/processing"
COMPLETED_DIR="$QUEUE_DIR/completed"
FAILED_DIR="$QUEUE_DIR/failed"
INSTANCES_DIR="$PROJECT_ROOT/terraform/instances"

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
    mkdir -p "$QUEUE_DIR" "$PROCESSING_DIR" "$COMPLETED_DIR" "$FAILED_DIR" "$INSTANCES_DIR"
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

# Check if jq is available for JSON processing
check_jq() {
    if ! command -v jq &> /dev/null; then
        error_exit "jq is not installed. Please install jq for JSON processing."
    fi
}

# Generate unique instance name based on template and app name
generate_instance_name() {
    local template_name="$1"
    local app_name="$2"
    local environment="$3"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    echo "${app_name}-${environment}-${timestamp}"
}

# Create instance-specific Terraform configuration
create_instance_config() {
    local template_name="$1"
    local instance_name="$2"
    local request_config="$3"
    
    local template_dir="$TERRAFORM_TEMPLATES_DIR/$template_name"
    local instance_dir="$INSTANCES_DIR/$instance_name"
    
    log "Creating instance configuration for $instance_name using template $template_name"
    
    # Verify template exists
    if [[ ! -d "$template_dir" ]]; then
        error_exit "Template not found: $template_dir"
    fi
    
    # Create instance directory
    mkdir -p "$instance_dir"
    
    # Copy template files
    cp -r "$template_dir"/* "$instance_dir/"
    
    # Create terraform.tfvars.json from request configuration
    echo "$request_config" | jq '.' > "$instance_dir/terraform.tfvars.json"
    
    log "Instance configuration created at: $instance_dir"
    echo "$instance_dir"
}

# Apply Terraform for a specific instance
apply_instance() {
    local instance_dir="$1"
    local instance_name="$2"
    
    log "Applying Terraform for instance: $instance_name"
    
    cd "$instance_dir"
    
    # Initialize Terraform
    log "Initializing Terraform for $instance_name..."
    if ! terraform init -no-color; then
        error_exit "Terraform initialization failed for $instance_name"
    fi
    
    # Validate configuration
    log "Validating Terraform configuration for $instance_name..."
    if ! terraform validate -no-color; then
        error_exit "Terraform validation failed for $instance_name"
    fi
    
    # Plan the changes
    log "Planning Terraform changes for $instance_name..."
    if ! terraform plan -no-color -var-file=terraform.tfvars.json -out=tfplan; then
        error_exit "Terraform plan failed for $instance_name"
    fi
    
    # Apply the changes
    log "Applying Terraform changes for $instance_name..."
    if ! terraform apply -no-color -auto-approve tfplan; then
        error_exit "Terraform apply failed for $instance_name"
    fi
    
    # Get outputs
    log "Getting Terraform outputs for $instance_name..."
    terraform output -json > terraform-outputs.json 2>/dev/null || echo "{}" > terraform-outputs.json
    
    log "Terraform apply completed successfully for $instance_name"
}

# Process a single request file
process_request() {
    local request_file="$1"
    local processing_file="$PROCESSING_DIR/$(basename "$request_file")"
    
    log "Processing request: $(basename "$request_file")"
    
    # Move to processing directory
    mv "$request_file" "$processing_file"
    
    # Parse request
    local request_id=$(jq -r '.id' "$processing_file")
    local resource_type=$(jq -r '.resource_type' "$processing_file")
    local resource_config=$(jq '.resource_config' "$processing_file")
    
    log "Request ID: $request_id"
    log "Resource Type: $resource_type"
    
    # Determine template based on resource type
    local template_name=""
    case "$resource_type" in
        "web_app")
            template_name="web-app-simple"
            ;;
        "api_service")
            template_name="api-simple"
            ;;
        *)
            error_exit "Unknown resource type: $resource_type"
            ;;
    esac
    
    log "Using template: $template_name"
    
    # Extract app/service name and environment from config
    local app_name=$(echo "$resource_config" | jq -r '.app_name // .service_name // "app"')
    local environment=$(echo "$resource_config" | jq -r '.environment // "dev"')
    
    # Generate instance name
    local instance_name=$(generate_instance_name "$template_name" "$app_name" "$environment")
    
    # Create instance configuration
    local instance_dir=$(create_instance_config "$template_name" "$instance_name" "$resource_config")
    
    # Apply Terraform
    if apply_instance "$instance_dir" "$instance_name"; then
        # Get outputs
        local outputs=$(cat "$instance_dir/terraform-outputs.json")
        
        # Update request with outputs
        jq --argjson outputs "$outputs" '.terraform_output = $outputs | .status = "COMPLETED"' "$processing_file" > "$COMPLETED_DIR/$(basename "$request_file")"
        
        log "Request completed successfully: $request_id"
        log "Instance created: $instance_name at $instance_dir"
        
        # Clean up processing file
        rm "$processing_file"
        
        return 0
    else
        # Move to failed directory with error info
        jq '.status = "FAILED" | .error_message = "Terraform apply failed"' "$processing_file" > "$FAILED_DIR/$(basename "$request_file")"
        rm "$processing_file"
        
        log "Request failed: $request_id"
        return 1
    fi
}

# Process all pending requests
process_queue() {
    log "Processing queue..."
    
    local processed=0
    local failed=0
    
    # Process all .json files in the pending directory
    for request_file in "$QUEUE_DIR/pending"/*.json; do
        if [[ -f "$request_file" ]]; then
            if process_request "$request_file"; then
                ((processed++))
            else
                ((failed++))
            fi
        fi
    done
    
    log "Queue processing completed. Processed: $processed, Failed: $failed"
    return 0
}

# List all active instances
list_instances() {
    log "Active instances:"
    
    if [[ -d "$INSTANCES_DIR" ]]; then
        for instance_dir in "$INSTANCES_DIR"/*; do
            if [[ -d "$instance_dir" ]]; then
                local instance_name=$(basename "$instance_dir")
                local state_file="$instance_dir/terraform.tfstate"
                
                if [[ -f "$state_file" ]]; then
                    local resources=$(terraform -chdir="$instance_dir" state list 2>/dev/null | wc -l || echo "0")
                    log "  - $instance_name ($resources resources)"
                else
                    log "  - $instance_name (no state file)"
                fi
            fi
        done
    else
        log "  No instances directory found"
    fi
}

# Cleanup old instances (optional)
cleanup_instances() {
    local days_old="${1:-30}"
    
    log "Cleaning up instances older than $days_old days..."
    
    if [[ -d "$INSTANCES_DIR" ]]; then
        find "$INSTANCES_DIR" -maxdepth 1 -type d -mtime "+$days_old" -exec rm -rf {} \; 2>/dev/null || true
        log "Cleanup completed"
    fi
}

# Main execution
main() {
    log "Starting template-based provisioning processor..."
    
    # Initialize
    init_directories
    check_terraform
    check_aws
    check_jq
    
    # Process command line arguments
    case "${1:-process}" in
        "process")
            process_queue
            ;;
        "list")
            list_instances
            ;;
        "cleanup")
            cleanup_instances "${2:-30}"
            ;;
        *)
            echo "Usage: $0 [process|list|cleanup] [days_for_cleanup]"
            echo "  process: Process pending requests (default)"
            echo "  list: List active instances"
            echo "  cleanup: Cleanup old instances (default: 30 days)"
            exit 1
            ;;
    esac
    
    log "Template-based provisioning processor completed"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
