# Job Handler Components in Mini IPCs Project

## 🎯 **Primary Job Handlers**

### 1. **Template Processing Scripts** (Main Job Handlers)

#### **`apply-templates.sh`** - Template Job Processor
```bash
# Location: /scripts/apply-templates.sh
# Purpose: Main job handler for template-based infrastructure provisioning
# Job Types: web_app, api_service template deployments
```

**Responsibilities:**
- Processes requests from `queue/pending/` directory
- Creates unique Terraform instances per request
- Executes Terraform apply for each template
- Manages job lifecycle: pending → processing → completed/failed

#### **`watch-templates.sh`** - Continuous Job Monitor
```bash
# Location: /scripts/watch-templates.sh  
# Purpose: Background job watcher and scheduler
# Monitoring: Real-time queue monitoring with inotify/polling
```

**Responsibilities:**
- Continuously monitors queue for new jobs
- Triggers `apply-templates.sh` when jobs arrive
- Handles background job processing
- Provides job status monitoring

### 2. **Queue Infrastructure** (Job Queue System)

#### **`FileBasedRequestQueue`** - Job Queue Implementation
```python
# Location: /backend/infrastructure/queue_adapter.py
# Purpose: File-based job queue using JSON files
# Interface: IRequestQueue
```

**Responsibilities:**
- **Enqueue**: Add jobs to `queue/pending/`
- **Dequeue**: Move jobs to `queue/processing/`
- **Status Tracking**: Move completed jobs to `queue/completed/` or `queue/failed/`

#### **`QueueProvisioningService`** - Job Service Orchestrator
```python
# Location: /backend/infrastructure/queue_adapter.py
# Purpose: Orchestrates job submission and status tracking
# Interface: IProvisioningService
```

**Responsibilities:**
- Submit jobs to queue
- Track job status and history
- Update job status from external processors
- Provide job listing and monitoring

### 3. **Approval Workflow Handler** (Governance Jobs)

#### **`approval-workflow.sh`** - Approval Job Processor
```bash
# Location: /scripts/approval-workflow.sh
# Purpose: Handles approval workflow jobs
# Job Types: approve, reject, process_approved
```

**Responsibilities:**
- Process approval/rejection jobs
- Move approved jobs from `queue/pending/` to `queue/approved/`
- Trigger processing of approved jobs
- Handle governance workflow

## 🔄 **Job Processing Flow**

### **1. Job Submission** (UI/API → Queue)
```
Developer UI/Admin UI → Backend API → QueueProvisioningService → FileBasedRequestQueue
```

### **2. Job Processing** (Queue → Terraform)
```
watch-templates.sh → apply-templates.sh → Terraform Templates → AWS Resources
```

### **3. Job Status Updates** (Processor → Storage)
```
apply-templates.sh → QueueProvisioningService → FileBasedRequestRepository
```

## 📂 **Job Storage Structure**

```
queue/
├── pending/           # New jobs waiting for processing
├── processing/        # Jobs currently being processed  
├── completed/         # Successfully completed jobs
├── failed/           # Failed jobs with error details
├── approved/         # Jobs approved but not yet processed
└── rejected/         # Rejected jobs with reasons
```

## 🛠 **Job Types Handled**

### **Template Jobs**
- **web_app**: Full-stack web applications (S3, CloudFront, EC2, RDS)
- **api_service**: API services (EC2, RDS, Security Groups, optional LB/Auto-scaling)

### **Workflow Jobs**  
- **approval**: Governance approval jobs
- **rejection**: Request rejection with reason
- **status_update**: Job status change notifications

## 🎮 **Job Handler Control**

### **VS Code Tasks** (Job Management)
- **"Watch Template Queue"**: Start continuous job processing
- **"Process Template Queue Once"**: Manual job processing
- **"List Active Instances"**: Show deployed job results
- **"Show Approval Workflow Status"**: Check governance job status

### **Admin UI** (Job Monitoring)
```python
# Location: /ui/admin_app.py
# Purpose: Visual job management interface
```
- Real-time job status monitoring
- Manual job approval/rejection
- Job processing triggers
- System status overview

## 🔧 **Job Handler Configuration**

### **Environment Variables**
```bash
QUEUE_DIR="queue"                    # Job queue directory
TERRAFORM_TEMPLATES_DIR="terraform/templates"  # Template job definitions
INSTANCES_DIR="terraform/instances"  # Job execution workspaces
```

### **Job Processing Settings**
```bash
WATCH_INTERVAL=5                     # Job polling interval (seconds)
TERRAFORM_AUTO_APPROVE=true          # Auto-approve Terraform jobs
BACKGROUND_PROCESSING=true           # Enable background job processing
```

## 🏗 **Job Handler Architecture Benefits**

1. **Separation of Concerns**: API handling separate from job execution
2. **Scalability**: File-based queue can be replaced with Redis/SQS
3. **Reliability**: Job status tracking and retry capabilities
4. **Governance**: Approval workflow for controlled execution
5. **Monitoring**: Real-time job status and history
6. **Template-based**: Reusable infrastructure patterns

## 🚀 **Usage Examples**

### Start Job Processing
```bash
# Start continuous job monitoring
./scripts/watch-templates.sh

# Process jobs once
./scripts/apply-templates.sh process
```

### Check Job Status
```bash
# List active job instances
./scripts/apply-templates.sh list

# Check job queue status
./scripts/check-integration.sh
```

The job handling system is **distributed across multiple components** but primarily handled by the **template processing scripts** (`apply-templates.sh` and `watch-templates.sh`) which are the main job execution engines in the system.
