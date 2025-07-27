# 🏗️ Internal Developer Platform (IDP)

A production-ready Internal Developer Platform showcasing real-world enterprise patterns for infrastructure provisioning, approval workflows, and developer self-service.

## 🌟 Key Features

- **🎯 Dual Interface System**: Separate UIs for developers and administrators
- **🔄 Approval Workflows**: Real-world governance with manual approval processes
- **🏗️ Clean Architecture**: Production-ready FastAPI backend with proper separation of concerns
- **🛠️ Terraform Integration**: Modular infrastructure as code with environment management
- **📊 Real-time Monitoring**: Track request lifecycle from submission to completion
- **🔒 Production Patterns**: Security, error handling, and enterprise-grade practices

## 🏛️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Developer UI  │    │    Admin UI     │    │   FastAPI API   │
│   (Port 8080)   │◄──►│   (Port 8081)   │◄──►│   (Port 8000)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 ▼
                    ┌─────────────────────────┐
                    │    Terraform Engine     │
                    │  ┌─────────────────────┐ │
                    │  │   S3 Module        │ │
                    │  │   EC2 Module       │ │
                    │  │   VPC Module       │ │
                    │  └─────────────────────┘ │
                    └─────────────────────────┘
```

## 🎨 User Experience

### For Developers:
1. **Request Resources**: Submit infrastructure requests through intuitive UI
2. **Track Progress**: Monitor request status in real-time
3. **Self-Service**: No need to contact ops team for standard resources

### For Administrators:
1. **Review Requests**: Comprehensive approval interface with request details
2. **Governance Controls**: Approve/reject with audit trails
3. **System Monitoring**: Infrastructure health and request analytics

## 📂 Project Structure

```
internal-platform-sample/
├── 📚 Documentation
│   ├── README.md                    # This file
│   ├── ARCHITECTURE.md              # Detailed system design
│   └── PROJECT_SUMMARY.md           # Project overview
├── 🔧 Backend (Clean Architecture)
│   ├── backend/
│   │   ├── main.py                  # FastAPI application entry
│   │   ├── domain/                  # Business logic & models
│   │   │   ├── models.py            # Core domain models
│   │   │   └── interfaces.py        # Business interfaces
│   │   ├── application/             # Use cases & orchestration
│   │   │   └── use_cases.py         # Application logic
│   │   ├── presentation/            # API controllers
│   │   │   └── api.py               # REST endpoints
│   │   └── infrastructure/          # External concerns
│   │       └── queue_adapter.py     # File system & queue adapters
├── 🎨 Frontend (Dual UI System)
│   ├── ui/
│   │   ├── app.py                   # Developer UI (Request submission)
│   │   └── admin_app.py             # Admin UI (Approval workflows)
├── 🏗️ Infrastructure (Terraform)
│   ├── terraform/
│   │   ├── modules/                 # Reusable infrastructure modules
│   │   │   ├── s3/                  # S3 bucket provisioning
│   │   │   ├── ec2/                 # EC2 instance management  
│   │   │   └── vpc/                 # VPC network setup
│   │   └── environments/            # Environment-specific configs
│   │       └── dev/                 # Development environment
├── 🔄 Automation
│   ├── scripts/
│   │   ├── start-uis.sh             # Launch both UIs
│   │   ├── approval-workflow.sh     # Process approvals
│   │   └── demo.sh                  # Demo runner
└── ⚙️ Configuration
    ├── pyproject.toml               # Dependencies & project config
    ├── activate.sh                  # Environment setup
    └── poetry.lock                  # Locked dependencies
```

## 🚀 Quick Start

### Prerequisites
- Python 3.11+
- Poetry
- AWS CLI configured
- Terraform installed

### 1. Clone & Setup
```bash
git clone https://github.com/NaserRaoofi/internal-platform-sample.git
cd internal-platform-sample

# Setup environment (installs dependencies and activates Poetry)
./activate.sh
```

### 2. Start the Platform
```bash
# Option 1: Start everything with one command
./scripts/start-uis.sh

# Option 2: Start components individually
# Terminal 1 - Backend API
poetry run uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000

# Terminal 2 - Developer UI  
poetry run python ui/app.py

# Terminal 3 - Admin UI
poetry run python ui/admin_app.py
```

### 3. Access the Platform
- **🏠 Backend API**: http://localhost:8000
- **📖 API Documentation**: http://localhost:8000/docs
- **👨‍💻 Developer UI**: http://localhost:8080 (Request resources)
- **👨‍⚖️ Admin UI**: http://localhost:8081 (Approve requests)

## 🎯 Usage Workflow

### Step 1: Developer Requests Infrastructure
1. Open Developer UI (http://localhost:8080)
2. Choose resource type (S3, EC2, or VPC)
3. Configure resource parameters
4. Submit request
5. Track status in real-time

### Step 2: Administrator Reviews & Approves
1. Open Admin UI (http://localhost:8081)
2. Review pending requests with full context
3. Approve or reject with reasons
4. Monitor processing status

### Step 3: Automatic Provisioning
1. Approved requests trigger Terraform automation
2. Infrastructure is provisioned in AWS
3. Status updates in real-time
4. Completion notifications

## 🛠️ Development

### Project Philosophy
This platform demonstrates **real-world enterprise patterns**:

- **Clean Architecture**: Domain-driven design with clear boundaries
- **Separation of Concerns**: UI, business logic, and infrastructure are decoupled  
- **Approval Workflows**: Manual governance for critical infrastructure
- **Audit Trails**: Complete request lifecycle tracking
- **Error Handling**: Robust error management and user feedback

### Adding New Resource Types
1. Create Terraform module in `terraform/modules/`
2. Add resource type to domain models
3. Update UI forms for new resource
4. Test end-to-end workflow

### Running Tests
```bash
poetry run pytest tests/ -v
```

### Code Formatting
```bash
poetry run black backend/ ui/
poetry run isort backend/ ui/
```

## 🏢 Real-World Applications

This platform demonstrates patterns used by:

- **Netflix**: Service provisioning with approval workflows
- **Spotify**: Infrastructure as code with governance
- **Airbnb**: Developer self-service with safety controls
- **Uber**: Multi-environment infrastructure management

## 📊 Monitoring & Observability

### Available Endpoints
- `GET /` - Health check
- `GET /requests` - List all requests
- `POST /requests` - Submit new request
- `PATCH /requests/{id}/status` - Update request status
- `GET /requests/{id}` - Get specific request details

### System Tools (Admin UI)
- **Terraform Operations**: Plan, apply, destroy infrastructure
- **Queue Management**: Monitor request processing
- **Health Checks**: API and AWS connectivity status

## 🔧 Configuration

### Environment Variables
```bash
# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key

# Platform Configuration  
API_BASE_URL=http://localhost:8000
TERRAFORM_DIR=terraform/environments/dev
```

### Terraform Setup
```bash
cd terraform/environments/dev
terraform init
terraform plan
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Built with Clean Architecture principles
- Inspired by real-world enterprise IDPs
- Demonstrates production-ready patterns
- Community-driven development approach

---

**🚀 Ready to explore modern infrastructure automation? Start with the Quick Start guide above!**

## Clean Architecture Layers

- **Domain**: Business models and interfaces
- **Application**: Use cases and business logic
- **Infrastructure**: External services and adapters
- **Presentation**: API routes and controllers
