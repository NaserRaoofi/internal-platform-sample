# Scripts Architecture Summary

## Current Scripts (After Cleanup)

### Core Template Processing
- **`apply-templates.sh`** - Template-based Terraform processor
  - Processes WebApp and API service requests
  - Creates unique instances using modular templates
  - Supports web-app-simple and api-simple templates
  - Manages instances in terraform/instances/ directory

- **`watch-templates.sh`** - Template queue watcher
  - Continuously monitors queue/pending/ directory
  - Auto-processes new template requests
  - Supports both inotify and polling modes
  - Integrates with apply-templates.sh

### System Management
- **`check-integration.sh`** - Comprehensive integration validator
  - Validates backend-Terraform connection
  - Checks all components: models, templates, modules, scripts
  - Provides colored status output with detailed diagnostics
  - Essential for troubleshooting and validation

- **`setup.sh`** - Development environment setup
  - Configures development dependencies
  - Sets up project structure
  - Initializes required directories

- **`start-uis.sh`** - UI management
  - Starts both Developer UI (port 8080) and Admin UI (port 8081)
  - Manages UI processes and dependencies
  - Handles Poetry environment activation

### Governance
- **`approval-workflow.sh`** - Approval workflow management
  - Manages request approval process
  - Provides status and approval commands
  - Integrates with queue system for governance

## Removed Scripts (Legacy/Deprecated)

### ❌ Deleted Scripts
- **`apply.sh`** - Old individual resource processor (used ec2, s3, vpc directly)
- **`apply-modern.sh`** - Intermediate version, still used old resource types
- **`watch.sh`** - Old queue watcher (called legacy apply.sh)
- **`demo.sh`** - Old demo script (used outdated API endpoints)

### Why They Were Removed
1. **Architecture Mismatch**: Used individual AWS resources instead of application templates
2. **Resource Type Incompatibility**: Expected "s3", "ec2" instead of "web_app", "api_service"
3. **No Template Support**: Couldn't handle web-app-simple or api-simple templates
4. **Outdated API**: Demo script used old endpoints and request formats
5. **Duplicate Functionality**: Superseded by template-based equivalents

## Architecture Flow (Current)

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Developer UI  │───▶│   Backend API    │───▶│  Queue (JSON files) │
│   (Port 8080)   │    │  (FastAPI)       │    │   /queue/pending/   │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
                                                           │
┌─────────────────┐    ┌──────────────────┐               │
│    Admin UI     │───▶│  Approval Flow   │               │
│   (Port 8081)   │    │   (Governance)   │               │
└─────────────────┘    └──────────────────┘               │
                                                           ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│  Terraform      │◀───│ Template         │◀───│  Queue Watcher      │
│  Instances      │    │ Processor        │    │ (watch-templates.sh)│
│ /instances/     │    │(apply-templates) │    └─────────────────────┘
└─────────────────┘    └──────────────────┘
```

## Template-Based Processing

### Request Types Supported
- **web_app**: Uses web-app-simple template
  - Provisions S3 + CloudFront + EC2 + RDS (optional)
  - Multi-runtime support (Node.js, Python, Go, Java)
  - Includes CDN, security groups, monitoring

- **api_service**: Uses api-simple template  
  - Provisions EC2 + RDS + Security Groups
  - Optional: Load Balancer, Auto Scaling, API Gateway
  - Includes monitoring, backup, cache options

### Instance Management
- Each request creates unique instance: `{app_name}-{environment}-{timestamp}`
- Isolated Terraform state per instance
- No resource conflicts between deployments
- Easy cleanup and management via terraform/instances/

## VS Code Tasks Integration

### Available Tasks
- **Watch Template Queue**: Start continuous queue monitoring
- **Process Template Queue Once**: Manual queue processing
- **Check Integration**: Validate system health
- **Setup Development Environment**: Initialize project
- **Start All UIs**: Launch both developer and admin interfaces
- **List Active Instances**: Show deployed instances
- **Show Approval Workflow Status**: Check pending approvals

## Best Practices

### For Development
1. Use `check-integration.sh` before starting work
2. Use `watch-templates.sh` for continuous processing
3. Monitor queue directories for request status
4. Use VS Code tasks for common operations

### For Production
1. Set up proper AWS credentials
2. Configure monitoring and logging
3. Use approval workflow for governance
4. Regular cleanup of old instances
5. Monitor terraform/instances/ directory size

## Migration Notes

The cleanup successfully removes all legacy individual resource handling while maintaining a clean, template-based architecture. The new system is more maintainable, scalable, and aligned with real-world application deployment patterns.
