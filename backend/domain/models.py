"""
Domain Models - Core business entities for resource provisioning.

These models represent the essential business concepts and are independent
of any external frameworks or infrastructure concerns.

Updated to support real-world application templates instead of individual resources.
"""

from datetime import datetime
from enum import Enum
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field


class ResourceType(str, Enum):
    """Supported resource types for provisioning."""
    # Application templates for real-world use cases
    WEB_APP = "web_app"
    API_SERVICE = "api_service"
    DATA_PIPELINE = "data_pipeline"


class RequestStatus(str, Enum):
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    FAILED = "failed"
    REJECTED = "rejected"


class WebAppRequest(BaseModel):
    """Domain model for web application provisioning request."""
    
    app_name: str = Field(..., description="Name of the web application", min_length=3, max_length=50)
    environment: str = Field("dev", description="Environment (dev, staging, prod)")
    
    # Frontend Configuration
    index_document: str = Field("index.html", description="Index document for the website")
    error_document: str = Field("error.html", description="Error document for the website")
    cors_allowed_origins: List[str] = Field(default=["*"], description="CORS allowed origins")
    
    # Backend Configuration
    backend_enabled: bool = Field(True, description="Enable backend API server")
    runtime: str = Field("nodejs", description="Runtime for API server (nodejs, python, java, go)")
    api_port: int = Field(8080, description="Port for the API server")
    instance_type: str = Field("t3.micro", description="EC2 instance type")
    enable_static_ip: bool = Field(False, description="Enable Elastic IP for backend")
    root_volume_size: int = Field(20, description="Root volume size in GB")
    
    # Database Configuration
    database_required: bool = Field(False, description="Enable database")
    database_type: str = Field("postgres", description="Database engine type")
    database_instance_class: str = Field("db.t3.micro", description="RDS instance class")
    database_storage_size: int = Field(20, description="Database storage size in GB")
    database_username: str = Field("appuser", description="Database username")
    
    # CDN Configuration
    cdn_enabled: bool = Field(True, description="Enable CloudFront CDN")
    cdn_price_class: str = Field("PriceClass_100", description="CloudFront price class")
    custom_domain: str = Field("", description="Custom domain name")
    ssl_certificate_arn: Optional[str] = Field(None, description="ACM certificate ARN")
    
    # Security and Network
    allowed_cidr_blocks: List[str] = Field(default=["0.0.0.0/0"], description="Allowed CIDR blocks")
    geo_restriction_type: str = Field("none", description="Geo restriction type")
    geo_restriction_locations: List[str] = Field(default=[], description="Geo restriction locations")
    
    # Operational Configuration
    monitoring_enabled: bool = Field(True, description="Enable monitoring and logging")
    backup_enabled: bool = Field(True, description="Enable automated backups")
    backup_retention_days: int = Field(7, description="Backup retention days")
    delete_protection: bool = Field(False, description="Enable deletion protection")
    load_balancer_enabled: bool = Field(False, description="Enable load balancer")
    access_logs_enabled: bool = Field(False, description="Enable CloudFront access logs")
    
    tags: Dict[str, str] = Field(default_factory=dict, description="Resource tags")


class ApiServiceRequest(BaseModel):
    """Domain model for API service provisioning request."""
    
    service_name: str = Field(..., description="Name of the API service", min_length=3, max_length=50)
    environment: str = Field("dev", description="Environment (dev, staging, prod)")
    
    # Runtime Configuration
    runtime: str = Field("python", description="Runtime/language (python, nodejs, java, go)")
    api_port: int = Field(8080, description="Port for the API server")
    instance_type: str = Field("t3.micro", description="EC2 instance type")
    enable_static_ip: bool = Field(False, description="Enable Elastic IP for API server")
    root_volume_size: int = Field(20, description="Root volume size in GB")
    
    # Database Configuration
    database_required: bool = Field(False, description="Require database")
    database_type: str = Field("postgres", description="Database engine type")
    database_instance_class: str = Field("db.t3.micro", description="RDS instance class")
    database_storage_size: int = Field(20, description="Database storage size in GB")
    database_username: str = Field("apiuser", description="Database username")
    
    # Cache Configuration
    redis_cache: bool = Field(False, description="Include Redis for caching")
    cache_node_type: str = Field("cache.t3.micro", description="ElastiCache node type")
    
    # Load Balancing and Scaling
    load_balancer: bool = Field(False, description="Enable Application Load Balancer")
    auto_scaling: bool = Field(False, description="Enable auto-scaling")
    min_instances: int = Field(1, description="Minimum number of instances")
    max_instances: int = Field(3, description="Maximum number of instances")
    target_cpu_utilization: int = Field(70, description="Target CPU utilization for scaling")
    
    # API Gateway Configuration
    api_gateway: bool = Field(False, description="Use API Gateway")
    api_gateway_type: str = Field("REST", description="API Gateway type (REST, HTTP)")
    throttle_rate: int = Field(1000, description="API throttle rate per second")
    throttle_burst: int = Field(2000, description="API throttle burst limit")
    
    # Security Configuration
    allowed_cidr_blocks: List[str] = Field(default=["0.0.0.0/0"], description="Allowed CIDR blocks")
    ssl_certificate_arn: Optional[str] = Field(None, description="ACM certificate ARN")
    enable_waf: bool = Field(False, description="Enable Web Application Firewall")
    
    # Monitoring and Backup
    monitoring_enabled: bool = Field(True, description="Enable monitoring and logging")
    backup_enabled: bool = Field(True, description="Enable automated backups")
    backup_retention_days: int = Field(7, description="Backup retention days")
    log_retention_days: int = Field(30, description="CloudWatch logs retention days")
    
    # Operational Configuration
    delete_protection: bool = Field(False, description="Enable deletion protection")
    maintenance_window: str = Field("sun:03:00-sun:04:00", description="Maintenance window")
    
    tags: Dict[str, str] = Field(default_factory=dict, description="Resource tags")


class ProvisioningRequest(BaseModel):
    """Generic provisioning request that wraps specific resource requests."""
    
    id: str = Field(..., description="Unique request identifier")
    requester: str = Field(..., description="Username of the requester")
    resource_type: ResourceType = Field(..., description="Type of resource to provision")
    resource_config: Dict[str, Any] = Field(..., description="Resource-specific configuration")
    status: RequestStatus = Field(RequestStatus.PENDING, description="Current request status")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="Request creation time")
    updated_at: Optional[datetime] = Field(None, description="Last update time")
    error_message: Optional[str] = Field(None, description="Error details if status is FAILED")
    terraform_output: Optional[Dict[str, Any]] = Field(None, description="Terraform execution output")
    approver: Optional[str] = Field(None, description="Username of the approver")
    rejection_reason: Optional[str] = Field(None, description="Reason for rejection if applicable")
    
    def mark_in_progress(self):
        """Mark request as in progress."""
        self.status = RequestStatus.IN_PROGRESS
        self.updated_at = datetime.utcnow()
    
    def mark_completed(self, terraform_output: Optional[Dict[str, Any]] = None):
        """Mark request as completed with optional Terraform output."""
        self.status = RequestStatus.COMPLETED
        self.updated_at = datetime.utcnow()
        if terraform_output:
            self.terraform_output = terraform_output
    
    def mark_failed(self, error_message: str):
        """Mark request as failed with error details."""
        self.status = RequestStatus.FAILED
        self.updated_at = datetime.utcnow()
        self.error_message = error_message
    
    def mark_approved(self, approver: str):
        """Mark request as approved."""
        self.approver = approver
        self.updated_at = datetime.utcnow()
    
    def mark_rejected(self, approver: str, reason: str = ""):
        """Mark request as rejected."""
        self.status = RequestStatus.REJECTED
        self.approver = approver
        self.rejection_reason = reason
        self.updated_at = datetime.utcnow()
