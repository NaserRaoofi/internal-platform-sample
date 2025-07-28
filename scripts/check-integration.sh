#!/bin/bash

# Integration Status Check Script
# Validates the complete backend-to-Terraform integration

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

status_ok() {
    echo -e "${GREEN}✓${NC} $*"
}

status_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

status_error() {
    echo -e "${RED}✗${NC} $*"
}

status_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

# Check backend models
check_backend_models() {
    log "${BLUE}Checking Backend Models...${NC}"
    
    local models_file="$PROJECT_ROOT/backend/domain/models.py"
    
    if [[ -f "$models_file" ]]; then
        status_ok "Models file exists"
        
        # Check for required classes
        if grep -q "class WebAppRequest" "$models_file"; then
            status_ok "WebAppRequest model found"
        else
            status_error "WebAppRequest model missing"
        fi
        
        if grep -q "class ApiServiceRequest" "$models_file"; then
            status_ok "ApiServiceRequest model found"
        else
            status_error "ApiServiceRequest model missing"
        fi
        
        if grep -q "class ResourceType" "$models_file"; then
            local web_app_enum=$(grep -A 5 "class ResourceType" "$models_file" | grep -c "WEB_APP\|web_app" || echo "0")
            local api_service_enum=$(grep -A 5 "class ResourceType" "$models_file" | grep -c "API_SERVICE\|api_service" || echo "0")
            
            if [[ "$web_app_enum" -gt 0 ]] && [[ "$api_service_enum" -gt 0 ]]; then
                status_ok "ResourceType enum properly configured for templates"
            else
                status_warning "ResourceType enum may need template values"
            fi
        else
            status_error "ResourceType enum missing"
        fi
    else
        status_error "Models file not found: $models_file"
    fi
    
    echo
}

# Check use cases
check_use_cases() {
    log "${BLUE}Checking Use Cases...${NC}"
    
    local use_cases_file="$PROJECT_ROOT/backend/application/use_cases.py"
    
    if [[ -f "$use_cases_file" ]]; then
        status_ok "Use cases file exists"
        
        if grep -q "CreateWebAppRequestUseCase\|CreateWebApplicationRequestUseCase" "$use_cases_file"; then
            status_ok "Web app use case found"
        else
            status_error "Web app use case missing"
        fi
        
        if grep -q "CreateApiServiceRequestUseCase" "$use_cases_file"; then
            status_ok "API service use case found"
        else
            status_error "API service use case missing"
        fi
    else
        status_error "Use cases file not found: $use_cases_file"
    fi
    
    echo
}

# Check queue infrastructure
check_queue_infrastructure() {
    log "${BLUE}Checking Queue Infrastructure...${NC}"
    
    local queue_file="$PROJECT_ROOT/backend/infrastructure/queue_adapter.py"
    
    if [[ -f "$queue_file" ]]; then
        status_ok "Queue adapter file exists"
        
        if grep -q "class FileBasedRequestQueue" "$queue_file"; then
            status_ok "File-based queue implementation found"
        fi
        
        if grep -q "class QueueProvisioningService" "$queue_file"; then
            status_ok "Queue provisioning service found"
        fi
    else
        status_error "Queue adapter file not found: $queue_file"
    fi
    
    # Check queue directory structure
    local queue_dir="$PROJECT_ROOT/queue"
    if [[ -d "$queue_dir" ]]; then
        status_ok "Queue directory exists"
        
        local pending_count=$(find "$queue_dir" -name "*.json" -type f 2>/dev/null | wc -l)
        status_info "Pending requests: $pending_count"
        
        for subdir in processing completed failed; do
            if [[ -d "$queue_dir/$subdir" ]]; then
                local count=$(find "$queue_dir/$subdir" -name "*.json" -type f 2>/dev/null | wc -l)
                status_info "$subdir requests: $count"
            fi
        done
    else
        status_warning "Queue directory not found (will be created on first use)"
    fi
    
    echo
}

# Check Terraform templates
check_terraform_templates() {
    log "${BLUE}Checking Terraform Templates...${NC}"
    
    local templates_dir="$PROJECT_ROOT/terraform/templates"
    
    if [[ -d "$templates_dir" ]]; then
        status_ok "Templates directory exists"
        
        # Check web-app-simple template
        if [[ -d "$templates_dir/web-app-simple" ]]; then
            status_ok "web-app-simple template found"
            
            local web_files=("main.tf" "variables.tf" "outputs.tf")
            for file in "${web_files[@]}"; do
                if [[ -f "$templates_dir/web-app-simple/$file" ]]; then
                    status_ok "  $file exists"
                else
                    status_error "  $file missing"
                fi
            done
        else
            status_error "web-app-simple template missing"
        fi
        
        # Check api-simple template
        if [[ -d "$templates_dir/api-simple" ]]; then
            status_ok "api-simple template found"
            
            local api_files=("main.tf" "variables.tf" "outputs.tf")
            for file in "${api_files[@]}"; do
                if [[ -f "$templates_dir/api-simple/$file" ]]; then
                    status_ok "  $file exists"
                else
                    status_error "  $file missing"
                fi
            done
        else
            status_error "api-simple template missing"
        fi
    else
        status_error "Templates directory not found: $templates_dir"
    fi
    
    echo
}

# Check Terraform modules
check_terraform_modules() {
    log "${BLUE}Checking Terraform Modules...${NC}"
    
    local modules_dir="$PROJECT_ROOT/terraform/modules"
    
    if [[ -d "$modules_dir" ]]; then
        status_ok "Modules directory exists"
        
        local expected_modules=("aws-ec2" "aws-s3" "aws-rds" "aws-cloudfront" "aws-security-group")
        
        for module in "${expected_modules[@]}"; do
            if [[ -d "$modules_dir/$module" ]]; then
                status_ok "$module module found"
                
                local module_files=("main.tf" "variables.tf" "outputs.tf")
                local missing_files=0
                for file in "${module_files[@]}"; do
                    if [[ ! -f "$modules_dir/$module/$file" ]]; then
                        ((missing_files++))
                    fi
                done
                
                if [[ "$missing_files" -eq 0 ]]; then
                    status_ok "  Complete module structure"
                else
                    status_warning "  Missing $missing_files file(s)"
                fi
            else
                status_error "$module module missing"
            fi
        done
    else
        status_error "Modules directory not found: $modules_dir"
    fi
    
    echo
}

# Check processing scripts
check_processing_scripts() {
    log "${BLUE}Checking Processing Scripts...${NC}"
    
    # Check template-based scripts
    local template_apply="$PROJECT_ROOT/scripts/apply-templates.sh"
    local template_watch="$PROJECT_ROOT/scripts/watch-templates.sh"
    
    if [[ -f "$template_apply" ]]; then
        if [[ -x "$template_apply" ]]; then
            status_ok "Template apply script found and executable"
        else
            status_warning "Template apply script found but not executable"
        fi
    else
        status_error "Template apply script missing: $template_apply"
    fi
    
    if [[ -f "$template_watch" ]]; then
        if [[ -x "$template_watch" ]]; then
            status_ok "Template watch script found and executable"
        else
            status_warning "Template watch script found but not executable"
        fi
    else
        status_error "Template watch script missing: $template_watch"
    fi
    
    # Check legacy scripts
    local legacy_apply="$PROJECT_ROOT/scripts/apply.sh"
    local legacy_watch="$PROJECT_ROOT/scripts/watch.sh"
    
    if [[ -f "$legacy_apply" ]]; then
        status_warning "Legacy apply script still present - should be removed"
    else
        status_ok "Legacy apply script removed (clean migration to templates)"
    fi
    
    if [[ -f "$legacy_watch" ]]; then
        status_warning "Legacy watch script still present - should be removed"
    else
        status_ok "Legacy watch script removed (clean migration to templates)"
    fi
    
    # Check additional useful scripts
    local integration_check="$PROJECT_ROOT/scripts/check-integration.sh"
    local setup_script="$PROJECT_ROOT/scripts/setup.sh"
    local start_uis="$PROJECT_ROOT/scripts/start-uis.sh"
    
    if [[ -f "$integration_check" ]] && [[ -x "$integration_check" ]]; then
        status_ok "Integration check script available"
    fi
    
    if [[ -f "$setup_script" ]] && [[ -x "$setup_script" ]]; then
        status_ok "Setup script available"
    fi
    
    if [[ -f "$start_uis" ]] && [[ -x "$start_uis" ]]; then
        status_ok "UI startup script available"
    fi
    
    echo
}

# Check instance management
check_instance_management() {
    log "${BLUE}Checking Instance Management...${NC}"
    
    local instances_dir="$PROJECT_ROOT/terraform/instances"
    
    if [[ -d "$instances_dir" ]]; then
        local instance_count=$(find "$instances_dir" -maxdepth 1 -type d | wc -l)
        instance_count=$((instance_count - 1))  # Subtract 1 for the instances directory itself
        
        status_ok "Instances directory exists"
        status_info "Active instances: $instance_count"
        
        if [[ "$instance_count" -gt 0 ]]; then
            for instance_dir in "$instances_dir"/*; do
                if [[ -d "$instance_dir" ]]; then
                    local instance_name=$(basename "$instance_dir")
                    local state_file="$instance_dir/terraform.tfstate"
                    
                    if [[ -f "$state_file" ]]; then
                        status_info "  $instance_name (has state)"
                    else
                        status_warning "  $instance_name (no state file)"
                    fi
                fi
            done
        fi
    else
        status_warning "Instances directory not found (will be created when needed)"
    fi
    
    echo
}

# Check API endpoints
check_api_endpoints() {
    log "${BLUE}Checking API Endpoints...${NC}"
    
    local api_file="$PROJECT_ROOT/backend/presentation/api.py"
    
    if [[ -f "$api_file" ]]; then
        status_ok "API file exists"
        
        # Check for template endpoints
        if grep -q "web.*app\|webapp" "$api_file" && grep -q "api.*service" "$api_file"; then
            status_ok "Template endpoints appear to be present"
        else
            status_warning "Template endpoints may need updating"
        fi
        
        # Check for queue integration
        if grep -q "ProvisioningService\|QueueProvisioningService" "$api_file"; then
            status_ok "Queue integration found in API"
        else
            status_warning "Queue integration may be missing"
        fi
    else
        status_error "API file not found: $api_file"
    fi
    
    echo
}

# Check dependencies
check_dependencies() {
    log "${BLUE}Checking Dependencies...${NC}"
    
    # Check for required tools
    local tools=("terraform" "jq" "python3")
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            local version=""
            case "$tool" in
                "terraform")
                    version=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || terraform version 2>/dev/null | head -1 || echo "unknown")
                    ;;
                "jq")
                    version=$(jq --version 2>/dev/null || echo "unknown")
                    ;;
                "python3")
                    version=$(python3 --version 2>/dev/null || echo "unknown")
                    ;;
            esac
            status_ok "$tool available ($version)"
        else
            status_error "$tool not found"
        fi
    done
    
    # Check for optional tools
    if command -v inotifywait >/dev/null 2>&1; then
        status_ok "inotify-tools available (real-time queue monitoring)"
    else
        status_warning "inotify-tools not available (falling back to polling)"
        status_info "Install with: sudo apt-get install inotify-tools"
    fi
    
    echo
}

# Summary
generate_summary() {
    log "${BLUE}Integration Summary${NC}"
    echo "=================="
    
    echo "Backend Models: WebAppRequest, ApiServiceRequest with comprehensive configuration"
    echo "Templates: web-app-simple, api-simple with modular service composition"
    echo "Processing: Template-aware scripts with unique instance creation"
    echo "Queue: File-based queue system with status tracking"
    echo "Instance Management: Isolated deployments in terraform/instances/"
    
    echo
    echo "Architecture Flow:"
    echo "1. UI → Backend API → Queue (JSON files)"
    echo "2. Watcher Script → Template Processor → Terraform Instance"
    echo "3. Unique instance per request with module composition"
    echo "4. Status tracking through queue directories"
    
    echo
    echo "Ready for testing with template-based application provisioning!"
}

# Main execution
main() {
    log "${GREEN}Mini IPCs Backend-Terraform Integration Check${NC}"
    echo "=============================================="
    echo
    
    check_backend_models
    check_use_cases
    check_queue_infrastructure
    check_terraform_templates
    check_terraform_modules
    check_processing_scripts
    check_instance_management
    check_api_endpoints
    check_dependencies
    generate_summary
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
