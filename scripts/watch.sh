#!/bin/bash

# Watch Queue Script - Continuously monitor and process requests
# This script watches the queue directory and processes requests as they arrive

set -e

# Configuration
WATCH_INTERVAL="${WATCH_INTERVAL:-10}"  # seconds
QUEUE_DIR="${QUEUE_DIR:-queue}"
PENDING_DIR="$QUEUE_DIR/pending"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WATCH]${NC} $1"
}

# Function to count pending requests
count_pending() {
    if [[ -d "$PENDING_DIR" ]]; then
        find "$PENDING_DIR" -name "*.json" 2>/dev/null | wc -l
    else
        echo 0
    fi
}

# Main watch loop
watch_queue() {
    log "Starting queue watcher (checking every ${WATCH_INTERVAL}s)"
    log "Watching directory: $PENDING_DIR"
    
    local last_count=0
    
    while true; do
        local current_count
        current_count=$(count_pending)
        
        if [[ $current_count -gt 0 ]]; then
            if [[ $current_count -ne $last_count ]]; then
                warning "Found $current_count pending request(s)"
            fi
            
            # Process the queue
            log "Processing queue..."
            if ./scripts/apply.sh; then
                success "Queue processing completed successfully"
            else
                log "Queue processing completed with some errors"
            fi
        else
            if [[ $last_count -gt 0 ]]; then
                log "No pending requests"
            fi
        fi
        
        last_count=$current_count
        sleep "$WATCH_INTERVAL"
    done
}

# Signal handlers for graceful shutdown
cleanup() {
    log "Received interrupt signal, shutting down gracefully..."
    exit 0
}

trap cleanup SIGINT SIGTERM

# Main execution
main() {
    # Check if apply script exists
    if [[ ! -f "scripts/apply.sh" ]]; then
        echo "Error: scripts/apply.sh not found" >&2
        exit 1
    fi
    
    # Make sure apply script is executable
    chmod +x scripts/apply.sh
    
    # Create queue directory if it doesn't exist
    mkdir -p "$PENDING_DIR"
    
    # Start watching
    watch_queue
}

main "$@"
