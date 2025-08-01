"""
API Routes - Infrastructure Management
=====================================
"""

import logging
import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from application.services import infrastructure_service
from domain.models import DeploymentRequest, RequestStatus, ResourceType

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1", tags=["infrastructure"])

# In-memory storage for deployment requests (in production, use database)
deployment_requests: Dict[str, DeploymentRequest] = {}


class CreateInfraRequest(BaseModel):
    """Request model for infrastructure creation"""

    resource_type: str = Field(
        ..., description="Type of infrastructure (ec2, s3, vpc, web_app)"
    )
    name: str = Field(..., description="Name/identifier for the resource")
    environment: str = Field(
        default="dev", description="Environment (dev, staging, prod)"
    )
    region: str = Field(default="us-east-1", description="AWS region")
    config: Dict[str, Any] = Field(
        default_factory=dict, description="Resource-specific configuration"
    )
    tags: Dict[str, str] = Field(
        default_factory=dict, description="Resource tags"
    )


class JobResponse(BaseModel):
    """Response model for job operations"""

    job_id: str
    status: str
    message: str
    created_at: str
    estimated_duration: Optional[str] = None


@router.post("/create-infra", response_model=JobResponse)
async def create_infrastructure(request: CreateInfraRequest):
    """Create infrastructure deployment request (requires admin approval)"""
    try:
        request_id = str(uuid.uuid4())
        created_at = datetime.utcnow()

        # Create deployment request instead of directly deploying
        deployment_request = DeploymentRequest(
            request_id=request_id,
            resource_type=ResourceType(request.resource_type),
            name=request.name,
            environment=request.environment,
            region=request.region,
            config=request.config,
            tags=request.tags,
            created_at=created_at,
        )

        # Store the request
        deployment_requests[request_id] = deployment_request

        return JobResponse(
            job_id=request_id,
            status="pending_approval",
            message=f"Deployment request created for {request.resource_type}. "
                   f"Waiting for admin approval.",
            created_at=created_at.isoformat(),
            estimated_duration="Pending approval",
        )

    except Exception as e:
        logger.error(f"Failed to queue infrastructure creation: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to queue job: {str(e)}"
        )


@router.post("/destroy-infra", response_model=JobResponse)
async def destroy_infrastructure(request: CreateInfraRequest):
    """Destroy infrastructure resources"""
    try:
        job_id = str(uuid.uuid4())
        created_at = datetime.utcnow().isoformat()

        # Use infrastructure service
        await infrastructure_service.destroy_infrastructure(
            job_id=job_id,
            resource_type=request.resource_type,
            name=request.name,
            environment=request.environment,
            region=request.region,
        )

        return JobResponse(
            job_id=job_id,
            status="queued",
            message=f"Infrastructure destruction queued for "
                   f"{request.resource_type}",
            created_at=created_at,
            estimated_duration="3-10 minutes",
        )

    except Exception as e:
        logger.error(f"Failed to queue infrastructure destruction: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to queue job: {str(e)}"
        )


# Admin endpoints for approval workflow
@router.get("/deployment-requests")
async def get_deployment_requests():
    """Get all deployment requests (admin endpoint)"""
    return {"requests": list(deployment_requests.values())}


class ApprovalRequest(BaseModel):
    """Request model for approving/rejecting deployment requests"""
    action: str = Field(..., description="'approve' or 'reject'")
    reason: Optional[str] = Field(None, description="Reason for rejection")


@router.post("/deployment-requests/{request_id}/approve")
async def approve_deployment_request(request_id: str, approval: ApprovalRequest):
    """Approve or reject a deployment request (admin endpoint)"""
    if request_id not in deployment_requests:
        raise HTTPException(status_code=404, detail="Request not found")
    
    request = deployment_requests[request_id]
    
    if request.status != RequestStatus.PENDING:
        raise HTTPException(
            status_code=400, 
            detail=f"Request is already {request.status}"
        )
    
    if approval.action == "approve":
        # Approve the request and start deployment
        request.status = RequestStatus.APPROVED
        request.approved_at = datetime.utcnow()
        request.approved_by = "admin"  # In real app, get from auth
        
        # Now actually create the infrastructure
        job_id = str(uuid.uuid4())
        request.job_id = job_id
        
        try:
            await infrastructure_service.create_infrastructure(
                job_id=job_id,
                resource_type=request.resource_type.value,
                name=request.name,
                environment=request.environment,
                region=request.region,
                config=request.config,
                tags=request.tags,
            )
            
            return {
                "message": "Request approved and deployment started",
                "job_id": job_id,
                "status": "approved",
            }
            
        except Exception as e:
            request.status = RequestStatus.FAILED
            logger.error(f"Failed to start deployment: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Failed to start deployment: {str(e)}"
            )
    
    elif approval.action == "reject":
        # Reject the request
        request.status = RequestStatus.REJECTED
        request.rejection_reason = approval.reason
        
        return {
            "message": "Request rejected",
            "reason": approval.reason,
            "status": "rejected",
        }
    
    else:
        raise HTTPException(
            status_code=400,
            detail="Action must be 'approve' or 'reject'"
        )
