#!/bin/bash

# Approval-Based Workflow Script
# This script implements a governance workflow where requests need approval

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
QUEUE_DIR="$PROJECT_ROOT/queue"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Show pending requests that need approval
show_pending_requests() {
    log "=== PENDING REQUESTS REQUIRING APPROVAL ==="
    
    local count=0
    for request_file in "$QUEUE_DIR/pending"/*.json; do
        [[ -f "$request_file" ]] || continue
        
        local filename=$(basename "$request_file")
        local request_id="${filename%.json}"
        
        echo ""
        echo "📋 Request ID: $request_id"
        echo "   File: $filename"
        
        # Extract and display key information
        python3 -c "
import json
with open('$request_file', 'r') as f:
    req = json.load(f)
    
print(f'   Requester: {req.get(\"requester\", \"unknown\")}')
print(f'   Resource Type: {req.get(\"resource_type\", \"unknown\")}')
print(f'   Created: {req.get(\"created_at\", \"unknown\")}')

if req.get('resource_type') == 's3':
    config = req.get('resource_config', {})
    print(f'   Bucket Name: {config.get(\"bucket_name\", \"unknown\")}')
    print(f'   Encryption: {config.get(\"encryption_enabled\", False)}')
    print(f'   Public Access: {config.get(\"public_read_access\", False)}')
elif req.get('resource_type') == 'ec2':
    config = req.get('resource_config', {})
    print(f'   Instance Type: {config.get(\"instance_type\", \"unknown\")}')
    print(f'   AMI ID: {config.get(\"ami_id\", \"unknown\")}')
elif req.get('resource_type') == 'vpc':
    config = req.get('resource_config', {})
    print(f'   CIDR Block: {config.get(\"cidr_block\", \"unknown\")}')
    print(f'   AZs: {config.get(\"availability_zones\", [])}')
"
        ((count++))
    done
    
    if [[ $count -eq 0 ]]; then
        log "No pending requests found."
    else
        log "Found $count request(s) requiring approval."
    fi
    
    return $count
}

# Approve a specific request
approve_request() {
    local request_id="$1"
    local approver="$2"
    
    local request_file="$QUEUE_DIR/pending/${request_id}.json"
    
    if [[ ! -f "$request_file" ]]; then
        log "ERROR: Request $request_id not found"
        return 1
    fi
    
    log "Approving request $request_id by $approver"
    
    # Add approval metadata
    python3 -c "
import json
from datetime import datetime

with open('$request_file', 'r') as f:
    req = json.load(f)

req['approval'] = {
    'approved_by': '$approver',
    'approved_at': datetime.utcnow().isoformat(),
    'status': 'approved'
}

with open('$request_file', 'w') as f:
    json.dump(req, f, indent=2)
"
    
    # Move to approved directory
    mkdir -p "$QUEUE_DIR/approved"
    mv "$request_file" "$QUEUE_DIR/approved/"
    
    log "Request $request_id approved and moved to approved queue"
}

# Reject a specific request
reject_request() {
    local request_id="$1"
    local approver="$2"
    local reason="$3"
    
    local request_file="$QUEUE_DIR/pending/${request_id}.json"
    
    if [[ ! -f "$request_file" ]]; then
        log "ERROR: Request $request_id not found"
        return 1
    fi
    
    log "Rejecting request $request_id by $approver: $reason"
    
    # Add rejection metadata
    python3 -c "
import json
from datetime import datetime

with open('$request_file', 'r') as f:
    req = json.load(f)

req['approval'] = {
    'rejected_by': '$approver',
    'rejected_at': datetime.utcnow().isoformat(),
    'status': 'rejected',
    'reason': '$reason'
}

with open('$request_file', 'w') as f:
    json.dump(req, f, indent=2)
"
    
    # Update API status
    python3 -c "
import requests
try:
    response = requests.patch(
        'http://localhost:8000/requests/$request_id/status',
        json={
            'status': 'failed',
            'error_message': 'Request rejected: $reason'
        },
        timeout=10
    )
    print(f'API status updated: {response.status_code}')
except Exception as e:
    print(f'Failed to update API: {e}')
"
    
    # Move to rejected directory
    mkdir -p "$QUEUE_DIR/rejected"
    mv "$request_file" "$QUEUE_DIR/rejected/"
    
    log "Request $request_id rejected and moved to rejected queue"
}

# Process approved requests
process_approved_requests() {
    log "Processing approved requests..."
    
    # Move approved requests back to pending for processing
    for approved_file in "$QUEUE_DIR/approved"/*.json; do
        [[ -f "$approved_file" ]] || continue
        
        local filename=$(basename "$approved_file")
        log "Moving approved request $filename to processing queue"
        mv "$approved_file" "$QUEUE_DIR/pending/"
    done
    
    # Run the automated processing
    log "Running automated terraform processing..."
    "$SCRIPT_DIR/apply-modern.sh"
}

# Interactive approval workflow
interactive_approval() {
    while true; do
        clear
        echo "🏢 Infrastructure Approval Workflow"
        echo "================================="
        
        if ! show_pending_requests; then
            echo ""
            echo "Press Enter to refresh, or 'q' to quit"
            read -r input
            [[ "$input" == "q" ]] && break
            continue
        fi
        
        echo ""
        echo "Actions:"
        echo "  approve <request_id>     - Approve a request"
        echo "  reject <request_id> <reason> - Reject a request"
        echo "  process                  - Process all approved requests"
        echo "  refresh                  - Refresh the list"
        echo "  quit                     - Exit"
        echo ""
        echo -n "Enter action: "
        
        read -r action request_id reason
        
        case "$action" in
            "approve")
                if [[ -n "$request_id" ]]; then
                    approve_request "$request_id" "$(whoami)"
                    echo "Press Enter to continue..."
                    read -r
                else
                    echo "Usage: approve <request_id>"
                    echo "Press Enter to continue..."
                    read -r
                fi
                ;;
            "reject")
                if [[ -n "$request_id" && -n "$reason" ]]; then
                    reject_request "$request_id" "$(whoami)" "$reason"
                    echo "Press Enter to continue..."
                    read -r
                else
                    echo "Usage: reject <request_id> <reason>"
                    echo "Press Enter to continue..."
                    read -r
                fi
                ;;
            "process")
                process_approved_requests
                echo "Press Enter to continue..."
                read -r
                ;;
            "refresh")
                continue
                ;;
            "quit"|"q"|"exit")
                break
                ;;
            *)
                echo "Unknown action: $action"
                echo "Press Enter to continue..."
                read -r
                ;;
        esac
    done
}

# Main function
main() {
    case "${1:-interactive}" in
        "show")
            show_pending_requests
            ;;
        "approve")
            approve_request "$2" "${3:-$(whoami)}"
            ;;
        "reject")
            reject_request "$2" "${3:-$(whoami)}" "${4:-No reason provided}"
            ;;
        "process")
            process_approved_requests
            ;;
        "interactive"|*)
            interactive_approval
            ;;
    esac
}

main "$@"
