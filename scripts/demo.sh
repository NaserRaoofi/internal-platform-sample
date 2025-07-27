#!/bin/bash

# Demo Script - Demonstrates the Internal Developer Platform
# This script shows the complete flow from request submission to processing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Demo configuration
API_BASE_URL="http://localhost:8000"
DEMO_DELAY=3

log() {
    echo -e "${BLUE}[DEMO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

section() {
    echo
    echo -e "${PURPLE}=== $1 ===${NC}"
    echo
}

# Wait for user input
wait_for_user() {
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read -r
}

# Check if API is running
check_api() {
    log "Checking if API is running..."
    if curl -s "$API_BASE_URL" > /dev/null; then
        success "API is running at $API_BASE_URL"
    else
        warning "API is not running. Please start it with:"
        echo "cd backend && poetry run uvicorn main:app --reload"
        exit 1
    fi
}

# Demo EC2 request
demo_ec2_request() {
    section "Demo: EC2 Instance Request"
    
    log "Submitting EC2 instance provisioning request..."
    
    local response
    response=$(curl -s -X POST "$API_BASE_URL/requests/ec2" \
        -H "Content-Type: application/json" \
        -d '{
            "instance_type": "t3.micro",
            "ami_id": "ami-0abcdef1234567890",
            "key_pair_name": "demo-key-pair",
            "security_group_ids": ["sg-0123456789abcdef0"],
            "tags": {
                "Environment": "demo",
                "Project": "internal-dev-platform"
            }
        }' \
        --get --data-urlencode "requester=demo-user")
    
    if [[ $? -eq 0 ]]; then
        local request_id
        request_id=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['request_id'])" 2>/dev/null || echo "unknown")
        success "EC2 request submitted successfully!"
        info "Request ID: $request_id"
        echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
        
        # Store for later status check
        echo "$request_id" > /tmp/demo_ec2_request_id
    else
        warning "Failed to submit EC2 request"
    fi
}

# Demo VPC request
demo_vpc_request() {
    section "Demo: VPC Request"
    
    log "Submitting VPC provisioning request..."
    
    local response
    response=$(curl -s -X POST "$API_BASE_URL/requests/vpc" \
        -H "Content-Type: application/json" \
        -d '{
            "cidr_block": "10.0.0.0/16",
            "enable_dns_hostnames": true,
            "enable_dns_support": true,
            "availability_zones": ["us-west-2a", "us-west-2b"],
            "public_subnet_cidrs": ["10.0.1.0/24", "10.0.2.0/24"],
            "private_subnet_cidrs": ["10.0.10.0/24", "10.0.20.0/24"],
            "tags": {
                "Environment": "demo",
                "Project": "internal-dev-platform"
            }
        }' \
        --get --data-urlencode "requester=demo-user")
    
    if [[ $? -eq 0 ]]; then
        local request_id
        request_id=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['request_id'])" 2>/dev/null || echo "unknown")
        success "VPC request submitted successfully!"
        info "Request ID: $request_id"
        echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
        
        # Store for later status check
        echo "$request_id" > /tmp/demo_vpc_request_id
    else
        warning "Failed to submit VPC request"
    fi
}

# Demo S3 request
demo_s3_request() {
    section "Demo: S3 Bucket Request"
    
    log "Submitting S3 bucket provisioning request..."
    
    local timestamp
    timestamp=$(date +%s)
    
    local response
    response=$(curl -s -X POST "$API_BASE_URL/requests/s3" \
        -H "Content-Type: application/json" \
        -d "{
            \"bucket_name\": \"demo-bucket-$timestamp\",
            \"versioning_enabled\": true,
            \"encryption_enabled\": true,
            \"public_read_access\": false,
            \"tags\": {
                \"Environment\": \"demo\",
                \"Project\": \"internal-dev-platform\",
                \"Timestamp\": \"$timestamp\"
            }
        }" \
        --get --data-urlencode "requester=demo-user")
    
    if [[ $? -eq 0 ]]; then
        local request_id
        request_id=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['request_id'])" 2>/dev/null || echo "unknown")
        success "S3 request submitted successfully!"
        info "Request ID: $request_id"
        echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
        
        # Store for later status check
        echo "$request_id" > /tmp/demo_s3_request_id
    else
        warning "Failed to submit S3 request"
    fi
}

# List all requests
demo_list_requests() {
    section "Demo: List All Requests"
    
    log "Fetching all provisioning requests..."
    
    local response
    response=$(curl -s "$API_BASE_URL/requests")
    
    if [[ $? -eq 0 ]]; then
        success "Retrieved request list successfully!"
        echo "$response" | python3 -c "
import sys, json
requests = json.load(sys.stdin)
print(f'Total requests: {len(requests)}')
for req in requests:
    print(f'- {req[\"id\"][:8]}... | {req[\"resource_type\"]} | {req[\"status\"]} | {req[\"requester\"]}')
" 2>/dev/null || echo "$response"
    else
        warning "Failed to retrieve request list"
    fi
}

# Check status of demo requests
demo_check_status() {
    section "Demo: Check Request Status"
    
    # Check EC2 request
    if [[ -f "/tmp/demo_ec2_request_id" ]]; then
        local ec2_id
        ec2_id=$(cat /tmp/demo_ec2_request_id)
        log "Checking EC2 request status: $ec2_id"
        
        local response
        response=$(curl -s "$API_BASE_URL/requests/$ec2_id")
        if [[ $? -eq 0 ]]; then
            local status
            status=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['status'])" 2>/dev/null || echo "unknown")
            info "EC2 Request Status: $status"
        fi
    fi
    
    # Check VPC request
    if [[ -f "/tmp/demo_vpc_request_id" ]]; then
        local vpc_id
        vpc_id=$(cat /tmp/demo_vpc_request_id)
        log "Checking VPC request status: $vpc_id"
        
        local response
        response=$(curl -s "$API_BASE_URL/requests/$vpc_id")
        if [[ $? -eq 0 ]]; then
            local status
            status=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['status'])" 2>/dev/null || echo "unknown")
            info "VPC Request Status: $status"
        fi
    fi
    
    # Check S3 request
    if [[ -f "/tmp/demo_s3_request_id" ]]; then
        local s3_id
        s3_id=$(cat /tmp/demo_s3_request_id)
        log "Checking S3 request status: $s3_id"
        
        local response
        response=$(curl -s "$API_BASE_URL/requests/$s3_id")
        if [[ $? -eq 0 ]]; then
            local status
            status=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['status'])" 2>/dev/null || echo "unknown")
            info "S3 Request Status: $status"
        fi
    fi
}

# Show queue status
demo_queue_status() {
    section "Demo: Queue Status"
    
    log "Checking queue directories..."
    
    local pending_count=0
    local processing_count=0
    local completed_count=0
    
    if [[ -d "queue/pending" ]]; then
        pending_count=$(find queue/pending -name "*.json" 2>/dev/null | wc -l)
    fi
    
    if [[ -d "queue/processing" ]]; then
        processing_count=$(find queue/processing -name "*.json" 2>/dev/null | wc -l)
    fi
    
    if [[ -d "queue/completed" ]]; then
        completed_count=$(find queue/completed -name "*.json" 2>/dev/null | wc -l)
    fi
    
    info "Pending requests: $pending_count"
    info "Processing requests: $processing_count"
    info "Completed requests: $completed_count"
    
    if [[ $pending_count -gt 0 ]]; then
        warning "There are pending requests. Run './scripts/apply.sh' to process them."
    fi
}

# Main demo flow
run_demo() {
    section "Internal Developer Platform Demo"
    
    echo "This demo will show you how to:"
    echo "1. Submit provisioning requests via API"
    echo "2. Check request status"
    echo "3. Monitor the queue system"
    echo
    
    wait_for_user
    
    # Check prerequisites
    check_api
    
    # Demo requests
    demo_ec2_request
    sleep $DEMO_DELAY
    
    demo_vpc_request
    sleep $DEMO_DELAY
    
    demo_s3_request
    sleep $DEMO_DELAY
    
    wait_for_user
    
    # Show results
    demo_list_requests
    sleep $DEMO_DELAY
    
    demo_check_status
    sleep $DEMO_DELAY
    
    demo_queue_status
    
    section "Demo Complete"
    
    echo "Next steps:"
    echo "1. Process the queue: ./scripts/apply.sh"
    echo "2. Watch the queue: ./scripts/watch.sh"
    echo "3. Check the UI: http://localhost:8080"
    echo "4. View API docs: http://localhost:8000/docs"
    echo
    
    # Cleanup temp files
    rm -f /tmp/demo_*_request_id
}

# Run the demo
run_demo "$@"
