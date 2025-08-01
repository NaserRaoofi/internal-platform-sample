# Workspace Management Strategy - Enterprise Platform Engineering

## 🏗️ Current State Analysis

### **File-Based Workspace Storage (Current)**
```
terraform/workspaces/
├── 1e8b3903-fc75-4abb-977d-eb6a8a8c887e/
├── 2866006a-86bb-43df-a11b-0bf73587149a/
├── 3c4eacbd-7a69-41b0-bae3-97c0c4a4b9e9/
└── ...
```

**Pros:**
- ✅ Terraform state naturally lives with workspace
- ✅ Easy to backup entire workspace
- ✅ Supports Terraform's native workspace model
- ✅ Git-friendly for infrastructure-as-code

**Cons:**
- ❌ No queryable metadata without filesystem scanning
- ❌ Difficult to implement permissions/RBAC
- ❌ No built-in audit trails
- ❌ Challenging for multi-user concurrent access
- ❌ Limited search and filtering capabilities

---

## 🎯 Recommended Hybrid Approach

### **Database-Backed Metadata + File-Based State**

This enterprise-grade approach combines the best of both worlds:

```sql
-- Workspace metadata in database
CREATE TABLE workspaces (
    id UUID PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    template_name VARCHAR(50) NOT NULL,
    environment VARCHAR(20) NOT NULL,
    user_id INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    status VARCHAR(20) DEFAULT 'active',
    
    -- Filesystem location
    workspace_path VARCHAR(500) NOT NULL,
    state_file_path VARCHAR(500) NOT NULL,
    
    -- Configuration
    terraform_version VARCHAR(20),
    config_hash VARCHAR(64),
    
    -- Metadata
    tags JSONB,
    description TEXT,
    cost_estimate_monthly DECIMAL(10,2),
    
    UNIQUE(name, environment, user_id)
);

-- Resource tracking
CREATE TABLE workspace_resources (
    id SERIAL PRIMARY KEY,
    workspace_id UUID REFERENCES workspaces(id),
    resource_type VARCHAR(50) NOT NULL,
    resource_name VARCHAR(100) NOT NULL,
    aws_resource_id VARCHAR(255),
    aws_arn VARCHAR(500),
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW()
);

-- Deployment history
CREATE TABLE workspace_deployments (
    id SERIAL PRIMARY KEY,
    workspace_id UUID REFERENCES workspaces(id),
    deployment_type VARCHAR(20) NOT NULL, -- 'create', 'update', 'destroy'
    status VARCHAR(20) NOT NULL, -- 'running', 'success', 'failed'
    started_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    terraform_output JSONB,
    error_message TEXT
);
```

### **Directory Structure Enhancement**
```
terraform/
├── workspaces/
│   ├── {workspace-id}/           # Terraform state and plans
│   │   ├── terraform.tfstate
│   │   ├── terraform.tfstate.backup
│   │   ├── terraform.tfplan
│   │   └── .terraform/
│   └── metadata/                 # Cached metadata files
│       ├── {workspace-id}.json
│       └── index.json
├── templates/                    # Template definitions
└── modules/                      # Reusable modules
```

---

## 🔧 Implementation Strategy

### **Phase 1: Enhanced Database Models**

```python
# Enhanced workspace model
class Workspace(Base):
    __tablename__ = "workspaces"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String(100), nullable=False)
    template_name = Column(String(50), nullable=False)
    environment = Column(String(20), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Filesystem paths
    workspace_path = Column(String(500), nullable=False)
    state_file_path = Column(String(500), nullable=False)
    
    # Configuration tracking
    terraform_version = Column(String(20))
    config_hash = Column(String(64))  # SHA256 of terraform config
    
    # Metadata
    tags = Column(JSON)
    description = Column(Text)
    cost_estimate_monthly = Column(Numeric(10, 2))
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Status tracking
    status = Column(String(20), default='active')  # active, creating, destroyed, error
    
    # Relationships
    user = relationship("User", back_populates="workspaces")
    resources = relationship("WorkspaceResource", back_populates="workspace")
    deployments = relationship("WorkspaceDeployment", back_populates="workspace")
    
    __table_args__ = (
        UniqueConstraint('name', 'environment', 'user_id', name='_workspace_name_env_user_uc'),
    )

class WorkspaceResource(Base):
    __tablename__ = "workspace_resources"
    
    id = Column(Integer, primary_key=True)
    workspace_id = Column(String, ForeignKey("workspaces.id"), nullable=False)
    resource_type = Column(String(50), nullable=False)
    resource_name = Column(String(100), nullable=False)
    aws_resource_id = Column(String(255))
    aws_arn = Column(String(500))
    status = Column(String(20), default='active')
    created_at = Column(DateTime, default=datetime.utcnow)
    
    workspace = relationship("Workspace", back_populates="resources")

class WorkspaceDeployment(Base):
    __tablename__ = "workspace_deployments"
    
    id = Column(Integer, primary_key=True)
    workspace_id = Column(String, ForeignKey("workspaces.id"), nullable=False)
    deployment_type = Column(String(20), nullable=False)  # create, update, destroy
    status = Column(String(20), nullable=False)  # running, success, failed
    started_at = Column(DateTime, default=datetime.utcnow)
    completed_at = Column(DateTime)
    terraform_output = Column(JSON)
    error_message = Column(Text)
    
    workspace = relationship("Workspace", back_populates="deployments")
```

### **Phase 2: Workspace Service Layer**

```python
class WorkspaceService:
    """Enterprise workspace management with database + filesystem hybrid approach"""
    
    def __init__(self):
        self.db_manager = SQLiteManager()
        self.workspace_root = Path("/terraform/workspaces")
    
    async def create_workspace(
        self, 
        name: str, 
        template: str, 
        environment: str, 
        user_id: int,
        config: Dict[str, Any]
    ) -> Workspace:
        """Create workspace with database metadata + filesystem structure"""
        
        workspace_id = str(uuid.uuid4())
        workspace_path = self.workspace_root / workspace_id
        
        # 1. Create database record first
        workspace = Workspace(
            id=workspace_id,
            name=name,
            template_name=template,
            environment=environment,
            user_id=user_id,
            workspace_path=str(workspace_path),
            state_file_path=str(workspace_path / "terraform.tfstate"),
            config_hash=self._hash_config(config),
            tags=config.get('tags', {}),
            description=config.get('description', ''),
            status='creating'
        )
        
        with self.db_manager.get_session() as session:
            session.add(workspace)
            session.commit()
        
        # 2. Create filesystem structure
        workspace_path.mkdir(parents=True, exist_ok=True)
        
        # 3. Initialize Terraform workspace
        await self._initialize_terraform_workspace(workspace_path, template, config)
        
        return workspace
    
    async def list_workspaces(
        self, 
        user_id: int, 
        environment: Optional[str] = None,
        template: Optional[str] = None
    ) -> List[Dict]:
        """Fast workspace listing with database queries"""
        
        with self.db_manager.get_session() as session:
            query = session.query(Workspace).filter(Workspace.user_id == user_id)
            
            if environment:
                query = query.filter(Workspace.environment == environment)
            if template:
                query = query.filter(Workspace.template_name == template)
            
            workspaces = query.all()
            
            return [
                {
                    'id': w.id,
                    'name': w.name,
                    'template': w.template_name,
                    'environment': w.environment,
                    'status': w.status,
                    'created_at': w.created_at.isoformat(),
                    'resource_count': len(w.resources),
                    'cost_estimate': float(w.cost_estimate_monthly or 0)
                }
                for w in workspaces
            ]
```

---

## 🔍 Benefits of Hybrid Approach

### **1. Performance & Scalability**
- ⚡ Database queries for filtering/searching (ms vs seconds)
- 📊 Efficient cost aggregation and reporting
- 🔄 Concurrent access with proper locking

### **2. Security & Compliance**
- 🔐 RBAC through database permissions
- 📝 Complete audit trails in database
- 🏢 Enterprise backup strategies for both DB and files

### **3. Developer Experience**
- 🔍 Fast workspace discovery and filtering
- 📈 Real-time cost tracking and alerts
- 🚀 GitOps integration with metadata sync

### **4. Operational Excellence**
- 📊 Comprehensive monitoring and observability
- 🔄 Automated cleanup and lifecycle management
- 🏥 Health checks for workspace consistency

---

## 🎯 Migration Strategy

### **1. Backward Compatibility**
- Keep existing file-based workspaces functional
- Add database metadata gradually
- Provide migration tools for existing workspaces

### **2. Incremental Rollout**
- Phase 1: Read-only database metadata
- Phase 2: Database-first for new workspaces
- Phase 3: Migrate existing workspaces
- Phase 4: Deprecate pure file-based approach

### **3. Zero-Downtime Migration**
```bash
# Migration script example
./migrate-workspaces.py \
  --source-dir /terraform/workspaces \
  --dry-run \
  --batch-size 10
```

---

This hybrid approach provides enterprise-grade workspace management while maintaining Terraform best practices and ensuring seamless developer experience.
