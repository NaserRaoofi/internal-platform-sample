#!/bin/bash

# Start both UI applications for the Internal Developer Platform
# Developer UI (Port 8080) and Admin UI (Port 8081)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Check if Poetry is available
check_poetry() {
    export PATH="$HOME/.local/bin:$PATH"
    if ! command -v poetry &> /dev/null; then
        echo "Error: Poetry not found in PATH"
        exit 1
    fi
}

# Start Developer UI
start_developer_ui() {
    log "Starting Developer UI on port 8080..."
    cd "$PROJECT_ROOT"
    export PATH="$HOME/.local/bin:$PATH"
    poetry run python ui/app.py &
    DEV_UI_PID=$!
    echo $DEV_UI_PID > /tmp/dev_ui.pid
    log "Developer UI started with PID: $DEV_UI_PID"
}

# Start Admin UI
start_admin_ui() {
    log "Starting Admin UI on port 8081..."
    cd "$PROJECT_ROOT"
    export PATH="$HOME/.local/bin:$PATH"
    poetry run python ui/admin_app.py &
    ADMIN_UI_PID=$!
    echo $ADMIN_UI_PID > /tmp/admin_ui.pid
    log "Admin UI started with PID: $ADMIN_UI_PID"
}

# Stop UIs
stop_uis() {
    log "Stopping UI applications..."
    
    if [[ -f /tmp/dev_ui.pid ]]; then
        DEV_PID=$(cat /tmp/dev_ui.pid)
        if kill -0 $DEV_PID 2>/dev/null; then
            kill $DEV_PID
            log "Developer UI stopped"
        fi
        rm -f /tmp/dev_ui.pid
    fi
    
    if [[ -f /tmp/admin_ui.pid ]]; then
        ADMIN_PID=$(cat /tmp/admin_ui.pid)
        if kill -0 $ADMIN_PID 2>/dev/null; then
            kill $ADMIN_PID
            log "Admin UI stopped"
        fi
        rm -f /tmp/admin_ui.pid
    fi
    
    # Also kill any Python UI processes
    pkill -f "ui/app.py" 2>/dev/null || true
    pkill -f "ui/admin_app.py" 2>/dev/null || true
}

# Show status
show_status() {
    echo ""
    echo "🎯 Internal Developer Platform - UI Status"
    echo "=========================================="
    echo ""
    echo "🔗 Access URLs:"
    echo "   Developer UI: http://localhost:8080 (Request services)"
    echo "   Admin UI:     http://localhost:8081 (Approve/Process requests)"
    echo "   Backend API:  http://localhost:8000 (API endpoints)"
    echo "   API Docs:     http://localhost:8000/docs (Interactive API docs)"
    echo ""
    echo "📱 Running Services:"
    
    # Check if backend is running
    if curl -s http://localhost:8000/ >/dev/null 2>&1; then
        echo "   ✅ Backend API (Port 8000)"
    else
        echo "   ❌ Backend API (Port 8000) - NOT RUNNING"
    fi
    
    # Check developer UI
    if [[ -f /tmp/dev_ui.pid ]] && kill -0 $(cat /tmp/dev_ui.pid) 2>/dev/null; then
        echo "   ✅ Developer UI (Port 8080)"
    else
        echo "   ❌ Developer UI (Port 8080) - NOT RUNNING"
    fi
    
    # Check admin UI
    if [[ -f /tmp/admin_ui.pid ]] && kill -0 $(cat /tmp/admin_ui.pid) 2>/dev/null; then
        echo "   ✅ Admin UI (Port 8081)"
    else
        echo "   ❌ Admin UI (Port 8081) - NOT RUNNING"
    fi
    
    echo ""
}

# Cleanup on exit
cleanup() {
    log "Cleaning up..."
    stop_uis
}

# Main function
main() {
    case "${1:-start}" in
        "start")
            log "Starting Internal Developer Platform UIs..."
            check_poetry
            
            # Stop any existing UIs
            stop_uis
            sleep 2
            
            # Start both UIs
            start_developer_ui
            sleep 3
            start_admin_ui
            sleep 3
            
            show_status
            
            log "Both UIs started successfully!"
            log "Press Ctrl+C to stop all services"
            
            # Wait for interrupt
            trap cleanup EXIT INT TERM
            while true; do
                sleep 10
                
                # Check if processes are still running
                if [[ -f /tmp/dev_ui.pid ]] && ! kill -0 $(cat /tmp/dev_ui.pid) 2>/dev/null; then
                    log "Developer UI process died, restarting..."
                    start_developer_ui
                fi
                
                if [[ -f /tmp/admin_ui.pid ]] && ! kill -0 $(cat /tmp/admin_ui.pid) 2>/dev/null; then
                    log "Admin UI process died, restarting..."
                    start_admin_ui
                fi
            done
            ;;
        "stop")
            stop_uis
            log "All UIs stopped"
            ;;
        "status")
            show_status
            ;;
        "restart")
            log "Restarting UIs..."
            stop_uis
            sleep 2
            $0 start
            ;;
        *)
            echo "Usage: $0 {start|stop|status|restart}"
            echo ""
            echo "Commands:"
            echo "  start   - Start both Developer and Admin UIs"
            echo "  stop    - Stop all UI processes"
            echo "  status  - Show status of all services"
            echo "  restart - Restart all UIs"
            exit 1
            ;;
    esac
}

main "$@"
