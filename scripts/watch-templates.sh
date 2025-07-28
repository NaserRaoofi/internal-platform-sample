#!/bin/bash

# Template-based Queue Watcher Script
# Continuously monitors and processes template-based provisioning requests

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUEUE_DIR="$(dirname "$SCRIPT_DIR")/queue"
APPLY_SCRIPT="$SCRIPT_DIR/apply-templates.sh"
WATCH_INTERVAL=5  # seconds

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] WATCHER: $*" >&2
}

# Signal handlers for graceful shutdown
STOP_WATCHING=0

handle_signal() {
    log "Received shutdown signal, stopping watcher..."
    STOP_WATCHING=1
}

trap 'handle_signal' SIGINT SIGTERM

# Check if apply script exists and is executable
check_apply_script() {
    if [[ ! -f "$APPLY_SCRIPT" ]]; then
        log "ERROR: Apply script not found: $APPLY_SCRIPT"
        exit 1
    fi
    
    if [[ ! -x "$APPLY_SCRIPT" ]]; then
        log "ERROR: Apply script is not executable: $APPLY_SCRIPT"
        log "Run: chmod +x $APPLY_SCRIPT"
        exit 1
    fi
}

# Check for pending requests
has_pending_requests() {
    [[ -d "$QUEUE_DIR/pending" ]] && [[ -n "$(find "$QUEUE_DIR/pending" -name "*.json" -type f 2>/dev/null)" ]]
}

# Count pending requests
count_pending_requests() {
    if [[ -d "$QUEUE_DIR/pending" ]]; then
        find "$QUEUE_DIR/pending" -name "*.json" -type f 2>/dev/null | wc -l
    else
        echo "0"
    fi
}

# Process queue once
process_queue() {
    local pending_count=$(count_pending_requests)
    
    if [[ "$pending_count" -gt 0 ]]; then
        log "Found $pending_count pending request(s), processing..."
        
        # Execute the template apply script
        if "$APPLY_SCRIPT" process; then
            log "Queue processing completed successfully"
        else
            log "ERROR: Queue processing failed"
        fi
    fi
}

# Watch for file changes (if inotify-tools is available)
watch_with_inotify() {
    log "Using inotify for real-time monitoring"
    
    # Monitor queue directory for new files
    inotifywait -m -e create -e moved_to --format '%w%f' "$QUEUE_DIR" 2>/dev/null | while read -r file; do
        if [[ "$STOP_WATCHING" -eq 1 ]]; then
            break
        fi
        
        if [[ "$file" == *.json ]]; then
            log "New request detected: $(basename "$file")"
            sleep 1  # Brief delay to ensure file is completely written
            process_queue
        fi
    done &
    
    local inotify_pid=$!
    
    # Wait for shutdown signal
    while [[ "$STOP_WATCHING" -eq 0 ]]; do
        sleep 1
    done
    
    # Kill inotify process
    kill $inotify_pid 2>/dev/null || true
}

# Watch using polling (fallback method)
watch_with_polling() {
    log "Using polling for monitoring (interval: ${WATCH_INTERVAL}s)"
    
    while [[ "$STOP_WATCHING" -eq 0 ]]; do
        process_queue
        sleep "$WATCH_INTERVAL"
    done
}

# Choose monitoring method
start_watching() {
    log "Starting template-based queue watcher..."
    log "Queue directory: $QUEUE_DIR"
    log "Apply script: $APPLY_SCRIPT"
    
    # Create queue directory if it doesn't exist
    mkdir -p "$QUEUE_DIR"
    
    # Check for initial pending requests
    local initial_count=$(count_pending_requests)
    if [[ "$initial_count" -gt 0 ]]; then
        log "Found $initial_count pending request(s) on startup"
        process_queue
    fi
    
    # Choose monitoring method based on available tools
    if command -v inotifywait >/dev/null 2>&1; then
        watch_with_inotify
    else
        log "inotify-tools not available, falling back to polling"
        log "Install inotify-tools for better performance: sudo apt-get install inotify-tools"
        watch_with_polling
    fi
}

# Status command
show_status() {
    log "Queue Watcher Status"
    log "==================="
    log "Queue directory: $QUEUE_DIR"
    log "Apply script: $APPLY_SCRIPT"
    log "Pending requests: $(count_pending_requests)"
    
    if [[ -d "$QUEUE_DIR" ]]; then
        local processing_count=0
        local completed_count=0
        local failed_count=0
        
        [[ -d "$QUEUE_DIR/processing" ]] && processing_count=$(find "$QUEUE_DIR/processing" -name "*.json" -type f 2>/dev/null | wc -l)
        [[ -d "$QUEUE_DIR/completed" ]] && completed_count=$(find "$QUEUE_DIR/completed" -name "*.json" -type f 2>/dev/null | wc -l)
        [[ -d "$QUEUE_DIR/failed" ]] && failed_count=$(find "$QUEUE_DIR/failed" -name "*.json" -type f 2>/dev/null | wc -l)
        
        log "Processing: $processing_count"
        log "Completed: $completed_count"
        log "Failed: $failed_count"
    fi
    
    # Show instance status
    "$APPLY_SCRIPT" list
}

# Main execution
main() {
    case "${1:-watch}" in
        "watch")
            check_apply_script
            start_watching
            ;;
        "process")
            check_apply_script
            process_queue
            ;;
        "status")
            show_status
            ;;
        "help"|"--help"|"-h")
            echo "Usage: $0 [watch|process|status|help]"
            echo ""
            echo "Commands:"
            echo "  watch   - Start continuous monitoring (default)"
            echo "  process - Process queue once and exit"
            echo "  status  - Show current status"
            echo "  help    - Show this help message"
            echo ""
            echo "Environment variables:"
            echo "  WATCH_INTERVAL - Polling interval in seconds (default: 5)"
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
