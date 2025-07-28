# 🏗️ Internal Developer Platform (IDP) v2.0.0

A production-ready Internal Developer Platform showcasing real-world enterprise patterns for infrastructure provisioning, approval workflows, and developer self-service with a modern React.js frontend.

## 🌟 Key Features

- **⚛️ Modern React UI**: Production-ready React.js frontend with TypeScript and TailwindCSS
- **🎯 Dual Dashboard System**: Separate developer and admin dashboards with role-based access
- **🔄 Approval Workflows**: Real-world governance with interactive approval processes
- **🏗️ Clean Architecture**: Production-ready FastAPI backend with proper separation of concerns
- **🛠️ Terraform Integration**: Modular infrastructure as code with template-based approach
- **📊 Real-time Monitoring**: Track request lifecycle with live status updates
- **🔒 Production Patterns**: Security, error handling, and enterprise-grade practices
- **📱 Responsive Design**: Mobile-friendly interface with modern UX patterns

## 🏛️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   React UI      │    │  Admin Portal   │    │   FastAPI API   │
│ (Developer +    │◄──►│  (Approval      │◄──►│   (Port 8000)   │
│  Admin Dashboards)   │   Workflows)    │    │                 │
│ (Port 3000)     │    │  Built-in UI    │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 ▼
                    ┌─────────────────────────┐
                    │  Terraform Templates   │
                    │  ┌─────────────────────┐ │
                    │  │  AWS Modules:      │ │
                    │  │  • S3 Buckets      │ │
                    │  │  • EC2 Instances   │ │
                    │  │  • RDS Databases   │ │
                    │  │  • CloudFront CDN  │ │
                    │  │  • Security Groups │ │
                    │  └─────────────────────┘ │
                    └─────────────────────────┘
```

## 🎨 User Experience

### For Developers:
1. **Modern Dashboard**: Clean, intuitive React interface with real-time data
2. **Request Resources**: Submit infrastructure requests through validated forms
3. **Track Progress**: Monitor request status with live updates and notifications
4. **Self-Service**: Complete autonomy for standard resource provisioning
5. **Mobile-Friendly**: Responsive design works on all devices

### For Administrators:
1. **Admin Dashboard**: Comprehensive approval interface with detailed analytics
2. **Review Requests**: Rich request details with approval/rejection workflows
3. **Governance Controls**: Role-based access with complete audit trails
4. **System Monitoring**: Infrastructure health, request analytics, and system metrics
5. **Bulk Operations**: Manage multiple requests efficiently

## 📂 Project Structure

```
internal-platform-sample/
├── 📚 Documentation
│   ├── README.md                    # This file
│   ├── ARCHITECTURE.md              # Detailed system design
│   ├── PROJECT_SUMMARY.md           # Project overview
│   ├── CLEANUP_SUMMARY.md           # Scripts cleanup documentation
│   ├── SCRIPTS_ARCHITECTURE.md     # Scripts architecture details
│   └── JOB_HANDLERS.md              # Job handler components overview
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
├── 🎨 Frontend (Modern React UI)
│   ├── ui/
│   │   ├── src/
│   │   │   ├── components/
│   │   │   │   ├── dashboards/
│   │   │   │   │   ├── DeveloperDashboard.tsx  # Developer interface
│   │   │   │   │   └── AdminDashboard.tsx      # Admin approval interface
│   │   │   │   ├── forms/
│   │   │   │   │   └── DeployServiceForm.tsx   # Service deployment form
│   │   │   │   └── ui/                        # Reusable UI components
│   │   │   ├── store/
│   │   │   │   └── appStore.ts                # Zustand state management
│   │   │   └── App.tsx                       # Main React application
│   │   ├── package.json                      # React dependencies
│   │   └── tailwind.config.js               # TailwindCSS configuration
├── 🏗️ Infrastructure (Template-Based Terraform)
│   ├── terraform/
│   │   ├── README.md               # Terraform documentation
│   │   ├── modules/                # Reusable AWS infrastructure modules
│   │   │   ├── aws-s3/             # S3 bucket provisioning
│   │   │   ├── aws-ec2/            # EC2 instance management  
│   │   │   ├── aws-rds/            # RDS database setup
│   │   │   ├── aws-cloudfront/     # CloudFront CDN distribution
│   │   │   └── aws-security-group/ # Security group management
│   │   ├── templates/              # Service deployment templates
│   │   │   ├── web-app-simple/     # Simple web application template
│   │   │   └── api-simple/         # API service template
│   │   ├── instances/              # Active deployment instances
│   │   └── environments/           # Environment configurations
├── 🔄 Automation
│   ├── scripts/
│   │   ├── apply-templates.sh       # Template-based deployment processor
│   │   ├── watch-templates.sh       # Watch for template changes
│   │   ├── check-integration.sh     # Integration testing
│   │   ├── approval-workflow.sh     # Approval workflow processor
│   │   ├── start-uis.sh            # Start both UI applications
│   │   └── setup.sh                 # Environment setup script
└── ⚙️ Configuration
    ├── pyproject.toml               # Dependencies & project config
    ├── activate.sh                  # Environment setup
    ├── poetry.lock                  # Locked dependencies
    ├── queue/                       # Request queue storage
    └── storage/                     # Persistent data storage
```

## 🚀 Quick Start

### Prerequisites
- Python 3.11+
- Poetry
- Node.js 18+
- npm or yarn
- AWS CLI configured
- Terraform installed

### 1. Clone & Setup
```bash
git clone https://github.com/NaserRaoofi/internal-platform-sample.git
cd internal-platform-sample

# Setup Python environment
./activate.sh

# Setup React UI
cd ui
npm install
cd ..
```

### 2. Start the Platform
```bash
# Option 1: Start with VS Code tasks (recommended)
# Open in VS Code and use the pre-configured tasks:
# - "Start Backend API"
# - "Start Frontend UI"

# Option 2: Start components manually
# Terminal 1 - Backend API
poetry run uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000

# Terminal 2 - React UI  
cd ui && npm start

# Option 3: Legacy Python UIs (if needed)
# ./scripts/start-uis.sh  # Starts old Python Flask UIs on ports 8080/8081
```

### 3. Access the Platform
- **🏠 Backend API**: http://localhost:8000
- **📖 API Documentation**: http://localhost:8000/docs
- **⚛️ React UI**: http://localhost:3000
  - 👨‍💻 Developer Dashboard: Switch role to "Developer"
  - 👨‍⚖️ Admin Dashboard: Switch role to "Admin"

## 🎯 Usage Workflow

### Step 1: Developer Requests Infrastructure
1. Open React UI (http://localhost:3000)
2. Switch to Developer role using the role selector
3. Navigate to Developer Dashboard
4. Click "🚀 Deploy New Service" or use the quick actions
5. Fill out the deployment form with service details
6. Submit request and track status in real-time

### Step 2: Administrator Reviews & Approves
1. Stay in React UI (http://localhost:3000)
2. Switch to Admin role using the role selector
3. Navigate to Admin Dashboard
4. Review pending requests in the approval queue
5. Click "✅ Approve" or "❌ Reject" with detailed reasons
6. Monitor processing status and system health

### Step 3: Automatic Provisioning
1. Approved requests trigger template-based Terraform automation
2. Infrastructure is provisioned in AWS using modular templates
3. Status updates in real-time across all dashboards
4. Completion notifications with deployment details

## 🛠️ Development

### Project Philosophy
This platform demonstrates **real-world enterprise patterns** with modern technology:

- **Clean Architecture**: Domain-driven design with clear boundaries
- **Modern Frontend**: React 18 with TypeScript, TailwindCSS, and Zustand
- **Component-Based Design**: Reusable UI components with proper separation
- **State Management**: Centralized state with Zustand for predictable updates
- **Form Validation**: React Hook Form with Zod for type-safe validation
- **Approval Workflows**: Manual governance for critical infrastructure
- **Audit Trails**: Complete request lifecycle tracking
- **Error Handling**: Robust error management and user feedback
- **Template-Based IaC**: Modular Terraform templates for rapid deployment

### Tech Stack Details
- **Frontend**: React 18.3.1, TypeScript 4.9.5, TailwindCSS 3.4.16
- **State Management**: Zustand 5.0.2
- **Forms**: React Hook Form 7.54.1 + Zod 3.24.1
- **Routing**: React Router 6+
- **Styling**: TailwindCSS with design system
- **Backend**: FastAPI with Clean Architecture
- **Infrastructure**: Terraform with AWS modules

### Adding New Resource Types
1. Create Terraform template in `terraform/templates/`
2. Add resource type to domain models (`backend/domain/models.py`)
3. Update React components for new resource type
4. Add form validation schemas
5. Test end-to-end workflow in both dashboards

### Running Tests
```bash
# Backend tests
poetry run pytest tests/ -v

# Frontend tests (when implemented)
cd ui && npm test
```

### Code Formatting
```bash
# Backend formatting
poetry run black backend/ 
poetry run isort backend/

# Frontend formatting
cd ui && npm run lint
cd ui && npm run format
```

## 🏢 Real-World Applications

This platform demonstrates patterns used by leading tech companies:

- **Netflix**: Service provisioning with approval workflows and self-service developer tools
- **Spotify**: Infrastructure as code with governance and template-based deployments
- **Airbnb**: Developer self-service with safety controls and modern React interfaces
- **Uber**: Multi-environment infrastructure management with real-time monitoring
- **Slack**: Modern developer tooling with comprehensive UI/UX design

## 📊 Monitoring & Observability

### Available Endpoints
- `GET /` - Health check
- `GET /requests` - List all requests
- `POST /requests` - Submit new request
- `PATCH /requests/{id}/status` - Update request status
- `GET /requests/{id}` - Get specific request details

### System Tools (Admin Dashboard)
- **Request Management**: Comprehensive approval workflows with detailed views
- **Template Operations**: Plan, apply, destroy infrastructure using templates
- **Queue Management**: Monitor request processing with real-time updates
- **Health Checks**: API connectivity and AWS service status
- **Analytics Dashboard**: Request statistics and system metrics
- **User Management**: Role-based access control and permissions

## 🔧 Configuration

### Environment Variables
```bash
# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key

# Platform Configuration  
API_BASE_URL=http://localhost:8000
TERRAFORM_TEMPLATES_DIR=terraform/templates
TERRAFORM_INSTANCES_DIR=terraform/instances
```

### Terraform Setup
```bash
cd terraform/templates/web-app-simple
terraform init
terraform plan
```

## � Additional Documentation

For detailed information about specific aspects of the platform:

- **🏗️ [ARCHITECTURE.md](ARCHITECTURE.md)**: Comprehensive system architecture and design patterns
- **📋 [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)**: High-level project overview and goals
- **🧹 [CLEANUP_SUMMARY.md](CLEANUP_SUMMARY.md)**: Documentation of scripts cleanup and modernization
- **⚙️ [SCRIPTS_ARCHITECTURE.md](SCRIPTS_ARCHITECTURE.md)**: Detailed scripts architecture and job handlers
- **🔧 [JOB_HANDLERS.md](JOB_HANDLERS.md)**: Job handler components and processing workflows
- **🏗️ [terraform/README.md](terraform/README.md)**: Terraform modules and templates documentation

## �📦 Dependencies

### Backend Dependencies
- FastAPI 0.104.1
- Uvicorn for ASGI server
- Pydantic for data validation
- Poetry for dependency management

### Frontend Dependencies  
- React 18.3.1
- TypeScript 4.9.5
- TailwindCSS 3.4.16
- Zustand 5.0.2
- React Hook Form 7.54.1
- Zod 3.24.1
- React Router DOM 6+

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Built with Clean Architecture principles and modern React patterns
- Inspired by real-world enterprise IDPs and developer tools
- Demonstrates production-ready patterns with cutting-edge frontend technology
- Community-driven development approach with open-source best practices
- Special thanks to the React, TypeScript, and TailwindCSS communities

---

**🚀 Ready to explore modern infrastructure automation with React? Start with the Quick Start guide above!**

## 🏗️ Clean Architecture Layers

- **Domain**: Business models and interfaces (`backend/domain/`)
- **Application**: Use cases and business logic (`backend/application/`)
- **Infrastructure**: External services and adapters (`backend/infrastructure/`)
- **Presentation**: API routes and React UI (`backend/presentation/`, `ui/src/`)

## 🎯 Key Improvements in v2.0.0

- **🆕 Modern React Frontend**: Complete rewrite from Python Flask to React 18 with TypeScript
- **📱 Responsive Design**: Mobile-first approach with TailwindCSS design system
- **🔧 Enhanced State Management**: Zustand for predictable state updates
- **📝 Advanced Forms**: React Hook Form with Zod validation for type safety
- **🎨 Component Library**: Reusable UI components with consistent design
- **🔄 Real-time Updates**: Live status updates across all dashboards
- **📊 Rich Analytics**: Enhanced admin dashboard with comprehensive metrics
- **🏗️ Template Architecture**: Improved Terraform templates for faster deployments
