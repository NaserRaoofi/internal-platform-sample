# Development Server

Professional development environment setup with comprehensive logging and Redis management.

## Features

### ✅ **Professional Logging System**
- **Structured Logging**: Timestamp, service name, log level, and message
- **Multiple Log Levels**: DEBUG, INFO, WARNING, ERROR, CRITICAL
- **Console & File Output**: Log to console and optionally to file
- **Log Rotation**: Automatic log file rotation to prevent disk space issues
- **Configurable Rotation**: Customizable file size limits and backup counts
- **Service-Specific Loggers**: Separate loggers for different services
- **Command-Line Control**: Configurable log levels via arguments
- **Process ID Tracking**: Include PID in file logs for multi-process debugging

### ✅ **Managed Redis with Docker**
- **Process Control**: Redis runs in a managed Docker container
- **Crash Detection**: Container health checks and restart policies
- **Logging**: Full Redis logs streamed to development console
- **Clean Shutdown**: Proper container cleanup on exit

### 🔧 **Two Redis Management Approaches**

#### 1. Docker Compose (Recommended)
```bash
# Uses docker-compose.dev.yml for declarative infrastructure
python dev_server.py
```

#### 2. Direct Docker Commands (Fallback)
```bash
# Falls back to direct docker run commands if compose unavailable
python dev_server.py
```

### 📦 **Dependencies**
- **Poetry**: Modern Python dependency management
- **Docker**: Containerized Redis with proper process management
- **Terraform**: Infrastructure as Code support

## Usage

### Basic Usage
```bash
# Start with default INFO logging
python dev_server.py

# Start with DEBUG logging
python dev_server.py --log-level DEBUG

# Log to file with rotation (default: 10MB, 5 backups)
python dev_server.py --log-file logs/dev_server.log

# Custom log rotation settings
python dev_server.py --log-file logs/app.log --log-max-size 5 --log-backup-count 3

# Complete configuration example
python dev_server.py --log-level DEBUG --log-file logs/debug.log --log-max-size 20 --log-backup-count 10
```

### Command Line Options
- `--log-level`: Set logging level (DEBUG, INFO, WARNING, ERROR)
- `--log-file`: Enable file logging with automatic rotation
- `--log-max-size`: Maximum file size in MB before rotation (default: 10)
- `--log-backup-count`: Number of backup files to keep (default: 5)

### Log Levels
- **DEBUG**: Detailed diagnostic information
- **INFO**: General operational messages (default)
- **WARNING**: Warning messages for potential issues
- **ERROR**: Error messages for failures
- **CRITICAL**: Critical errors that may cause shutdown

### Professional Logging Examples

```bash
# Console output with structured format:
2025-07-31 12:06:19 - dev-server - INFO - Internal Platform Development Server Starting
2025-07-31 12:06:19 - dev-server - INFO - Log rotation: logs/dev_server.log (max 10MB, keep 5)
2025-07-31 12:06:19 - dev-server - INFO - Checking system requirements...
2025-07-31 12:06:19 - dev-server - INFO - Required tool found: python3
2025-07-31 12:06:19 - dev-server - INFO - Required tool found: poetry
2025-07-31 12:06:19 - dev-server - INFO - Required tool found: docker
2025-07-31 12:06:20 - dev-server - INFO - All system requirements satisfied
2025-07-31 12:06:20 - dev-server - INFO - Starting Redis with Docker Compose...
2025-07-31 12:06:21 - service.fastapi-server - INFO - Starting application
2025-07-31 12:06:21 - service.rq-worker - INFO - Starting RQ worker...

# File output includes process ID for debugging:
2025-07-31 12:06:19,225 - dev-server - INFO - Log rotation: logs/dev_server.log (max 10MB, keep 5) - [PID:52043]
2025-07-31 12:06:19,226 - dev-server - INFO - Starting Redis with Docker Compose... - [PID:52043]
```

### Log Rotation Examples

```bash
# With 10MB max size and 5 backups, you'll get these files:
logs/dev_server.log     # Current active log file
logs/dev_server.log.1   # Most recent backup (when current reaches 10MB)
logs/dev_server.log.2   # Second backup
logs/dev_server.log.3   # Third backup
logs/dev_server.log.4   # Fourth backup
logs/dev_server.log.5   # Oldest backup (gets deleted when new rotation occurs)

# Custom rotation example (5MB files, 3 backups):
python dev_server.py --log-file logs/app.log --log-max-size 5 --log-backup-count 3
# Results in: app.log, app.log.1, app.log.2, app.log.3
```

## Services

- **FastAPI Server**: http://localhost:8000
- **API Documentation**: http://localhost:8000/docs
- **Redis**: localhost:6379 (managed Docker container)
- **Redis Queue Worker**: Background job processing
- **Redis Logs**: Real-time log streaming

## Professional Features

### Logging Benefits
- ✅ **Structured Format**: Consistent timestamp and service identification
- ✅ **Log Level Control**: Filter logs by importance level
- ✅ **File Persistence**: Save logs for analysis and debugging
- ✅ **Log Rotation**: Automatic file rotation prevents disk space issues
- ✅ **Configurable Rotation**: Control file size limits and backup retention
- ✅ **Service Separation**: Different loggers for different components
- ✅ **Process Tracking**: PID included in file logs for multi-process debugging
- ✅ **UTF-8 Encoding**: Proper character encoding for international text
- ✅ **Professional Standards**: Industry-standard logging practices

### Redis Management Benefits
- ✅ **Docker Container Management**: Professional process control
- ✅ **Health Monitoring**: Automatic monitoring with health checks
- ✅ **Crash Recovery**: Automatic restart on failure
- ✅ **Data Persistence**: AOF (Append Only File) for durability
- ✅ **Production Configuration**: Optimized Redis settings

## Shutdown

Use `Ctrl+C` to gracefully shutdown all services:
1. Stops FastAPI server
2. Terminates RQ worker
3. Stops Redis container
4. Logs shutdown completion

## Log Files and Rotation

When using `--log-file`, the system implements professional log rotation:

### Rotation Features
- **Automatic Rotation**: Files rotate when reaching the specified size limit
- **Backup Management**: Maintains a configurable number of backup files
- **No Data Loss**: Seamless rotation without losing log entries
- **Disk Space Control**: Prevents unlimited log file growth

### File Structure
```
logs/
├── dev_server.log      # Current active log (newest entries)
├── dev_server.log.1    # Previous log (rotated when limit reached)
├── dev_server.log.2    # Older backup
├── dev_server.log.3    # Older backup
└── dev_server.log.4    # Oldest backup (deleted when new rotation occurs)
```

### Log Formats
- **Console**: Human-readable format for real-time monitoring
- **File**: Enhanced format with process ID for debugging

**Console Format:**
```
2025-07-31 12:06:19 - dev-server - INFO - Starting Redis with Docker Compose...
```

**File Format:**
```
2025-07-31 12:06:19,225 - dev-server - INFO - Starting Redis with Docker Compose... - [PID:52043]
```

### Best Practices
- Use smaller file sizes (1-5MB) for development to see rotation in action
- Use larger file sizes (50-100MB) for production environments
- Keep 5-10 backup files for adequate history
- Monitor disk space in production environments
