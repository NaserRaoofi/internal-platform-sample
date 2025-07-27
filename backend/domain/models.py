"""
Domain Models - Core business entities for resource provisioning.

These models represent the essential business concepts and are independent
of any external frameworks or infrastructure concerns.
"""

from datetime import datetime
from enum import Enum
from typing import Optional, Dict, Any
from pydantic import BaseModel, Field


class ResourceType(str, Enum):
    EC2 = "ec2"
    VPC = "vpc"
    S3 = "s3"


class RequestStatus(str, Enum):
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    FAILED = "failed"


class EC2Request(BaseModel):
    """Domain model for EC2 instance provisioning request."""
    
    instance_type: str = Field(..., description="EC2 instance type (e.g., t3.micro)")
    ami_id: str = Field(..., description="Amazon Machine Image ID")
    key_pair_name: str = Field(..., description="SSH key pair name")
    security_group_ids: list[str] = Field(default_factory=list, description="Security group IDs")
    subnet_id: Optional[str] = Field(None, description="Subnet ID for placement")
    user_data: Optional[str] = Field(None, description="User data script")
    tags: Dict[str, str] = Field(default_factory=dict, description="Resource tags")


class VPCRequest(BaseModel):
    """Domain model for VPC provisioning request."""
    
    cidr_block: str = Field(..., description="CIDR block for VPC (e.g., 10.0.0.0/16)")
    enable_dns_hostnames: bool = Field(True, description="Enable DNS hostnames")
    enable_dns_support: bool = Field(True, description="Enable DNS support")
    availability_zones: list[str] = Field(..., description="List of AZs for subnets")
    public_subnet_cidrs: list[str] = Field(..., description="CIDR blocks for public subnets")
    private_subnet_cidrs: list[str] = Field(..., description="CIDR blocks for private subnets")
    tags: Dict[str, str] = Field(default_factory=dict, description="Resource tags")


class S3Request(BaseModel):
    """Domain model for S3 bucket provisioning request."""
    
    bucket_name: str = Field(..., description="S3 bucket name (must be globally unique)")
    versioning_enabled: bool = Field(False, description="Enable versioning")
    encryption_enabled: bool = Field(True, description="Enable server-side encryption")
    public_read_access: bool = Field(False, description="Allow public read access")
    lifecycle_rules: list[Dict[str, Any]] = Field(default_factory=list, description="Lifecycle rules")
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
