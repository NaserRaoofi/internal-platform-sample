"""
Data Models - Pydantic models for job requests and responses
===========================================================

Production-grade data validation and serialization models.
"""

from datetime import datetime
from typing import Dict, Any, Optional, List
from enum import Enum
from pydantic import BaseModel, Field

class JobStatus(str, Enum):
    """Job status enumeration"""
    QUEUED = "queued"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"

class JobAction(str, Enum):
    """Job action enumeration"""
    CREATE = "create"
    DESTROY = "destroy"
    UPDATE = "update"

class ResourceType(str, Enum):
    """Supported resource types"""
    EC2 = "ec2"
    S3 = "s3"
    VPC = "vpc"
    RDS = "rds"
    WEB_APP = "web_app"
    API_SERVICE = "api_service"

class JobRequest(BaseModel):
    """Job request model for queue processing"""
    job_id: str
    action: JobAction
    resource_type: ResourceType
    name: str
    environment: str = "dev"
    region: str = "us-east-1"
    config: Dict[str, Any] = Field(default_factory=dict)
    tags: Dict[str, str] = Field(default_factory=dict)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    parent_job_id: Optional[str] = None
    force: bool = False
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class JobLog(BaseModel):
    """Individual job log entry"""
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    level: str = "INFO"  # INFO, WARNING, ERROR
    message: str
    step: Optional[str] = None
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class JobProgress(BaseModel):
    """Job progress tracking"""
    current_step: str
    total_steps: int
    completed_steps: int
    percentage: int = Field(ge=0, le=100)
    estimated_completion: Optional[datetime] = None
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class JobResult(BaseModel):
    """Job execution result"""
    job_id: str
    status: JobStatus
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    error_message: Optional[str] = None
    terraform_output: Optional[Dict[str, Any]] = None
    resource_ids: Dict[str, str] = Field(default_factory=dict)  # AWS resource IDs
    logs: List[JobLog] = Field(default_factory=list)
    progress: Optional[JobProgress] = None
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class InfrastructureRequest(BaseModel):
    """High-level infrastructure request from frontend"""
    resource_type: ResourceType
    name: str
    environment: str = "dev"
    region: str = "us-east-1"
    config: Dict[str, Any] = Field(default_factory=dict)
    tags: Dict[str, str] = Field(default_factory=dict)

# EC2 specific models
class EC2Config(BaseModel):
    """EC2 instance configuration"""
    instance_type: str = "t3.micro"
    ami_id: Optional[str] = None
    key_pair_name: Optional[str] = None
    security_group_ids: List[str] = Field(default_factory=list)
    subnet_id: Optional[str] = None
    user_data: Optional[str] = None
    enable_monitoring: bool = True
    root_volume_size: int = 20
    root_volume_type: str = "gp3"

# S3 specific models
class S3Config(BaseModel):
    """S3 bucket configuration"""
    versioning_enabled: bool = True
    encryption_enabled: bool = True
    public_read_access: bool = False
    lifecycle_rules: List[Dict[str, Any]] = Field(default_factory=list)
    cors_rules: List[Dict[str, Any]] = Field(default_factory=list)
    website_enabled: bool = False

# Web App specific models
class WebAppConfig(BaseModel):
    """Web application stack configuration"""
    frontend_framework: str = "react"
    backend_framework: str = "fastapi"
    database_required: bool = True
    database_type: str = "postgres"
    ssl_enabled: bool = True
    cdn_enabled: bool = True
    custom_domain: Optional[str] = None
    auto_scaling: bool = False

# WebSocket message models
class WebSocketMessage(BaseModel):
    """WebSocket message structure"""
    type: str
    job_id: Optional[str] = None
    data: Dict[str, Any] = Field(default_factory=dict)
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }
