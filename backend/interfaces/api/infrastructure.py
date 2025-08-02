"""
API Routes - Infrastructure Management
=====================================
"""

import logging
import uuid
from datetime import datetime
from typing import Any, Dict, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from application.services import infrastructure_service
from infrastructure.database import db_manager

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1", tags=["infrastructure"])


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

        # Create deployment request data for database
        request_data = {
            "request_id": request_id,
            "user_id": 1,  # Default user ID - in real app, get from auth
            "resource_type": request.resource_type,
            "name": request.name,
            "environment": request.environment,
            "region": request.region,
            "config": request.config,
            "tags": request.tags,
            "status": "pending",
            "created_at": created_at,
        }

        # Store the request in database (async)
        await db_manager.create_deployment_request_async(request_data)

        return JobResponse(
            job_id=request_id,
            status="pending_approval",
            message=(
                f"Deployment request created for {request.resource_type}. "
                f"Waiting for admin approval."
            ),
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
    try:
        requests = await db_manager.get_all_deployment_requests_async()
        # Convert SQLAlchemy objects to dicts for JSON response
        requests_data = []
        for req in requests:
            # Map resource types to template names
            template_names = {
                "s3": "S3 Bucket Template",
                "ec2": "EC2 Instance Template",
                "web_app": "Web Application Template",
                "api_service": "API Service Template",
                "vpc": "VPC Template",
                "rds": "RDS Database Template"
            }
            
            resource_type_str = str(req.resource_type)
            template_name = template_names.get(
                resource_type_str,
                f"{resource_type_str.upper()} Template"
            )
            
            requests_data.append({
                "request_id": req.request_id,
                "user_id": req.user_id,
                "resource_type": req.resource_type,
                "template_name": template_name,
                "service_name": req.name,
                "name": req.name,
                "environment": req.environment,
                "region": req.region,
                "config": req.config,
                "tags": req.tags,
                "status": req.status,
                "created_at": (
                    req.created_at.isoformat()
                    if req.created_at is not None else None
                ),
                "approved_at": (
                    req.approved_at.isoformat()
                    if req.approved_at is not None else None
                ),
                "approved_by": req.approved_by,
                "rejection_reason": req.rejection_reason,
                "job_id": req.job_id,
            })
        return {"requests": requests_data}
    except Exception as e:
        logger.error(f"Failed to get deployment requests: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get deployment requests: {str(e)}"
        )


class ApprovalRequest(BaseModel):
    """Request model for approving/rejecting deployment requests"""
    action: str = Field(..., description="'approve' or 'reject'")
    reason: Optional[str] = Field(None, description="Reason for rejection")


@router.post("/deployment-requests/{request_id}/approve")
async def approve_deployment_request(
    request_id: str, approval: ApprovalRequest
):
    """Approve or reject a deployment request (admin endpoint)"""
    # Get request from database (async)
    request = await db_manager.get_deployment_request_async(request_id)
    if not request:
        raise HTTPException(status_code=404, detail="Request not found")

    if str(request.status) != "pending":
        raise HTTPException(
            status_code=400,
            detail=f"Request is already {request.status}"
        )
    
    if approval.action == "approve":
        # Approve the request and start deployment
        job_id = str(uuid.uuid4())
        
        updates = {
            "status": "approved",
            "approved_at": datetime.utcnow(),
            "approved_by": "admin",  # In real app, get from auth
            "job_id": job_id,
        }
        
        try:
            # Update request in database (async)
            await db_manager.update_deployment_request_async(
                request_id, updates
            )
            
            # Now actually create the infrastructure
            # Extract values from SQLAlchemy model
            resource_type = getattr(request, 'resource_type', '')
            name = getattr(request, 'name', '')
            environment = getattr(request, 'environment', 'dev')
            region = getattr(request, 'region', 'us-east-1')
            config = getattr(request, 'config', {}) or {}
            tags = getattr(request, 'tags', {}) or {}
            
            await infrastructure_service.create_infrastructure(
                job_id=job_id,
                resource_type=resource_type,
                name=name,
                environment=environment,
                region=region,
                config=config,
                tags=tags,
            )
            
            return {
                "message": "Request approved and deployment started",
                "job_id": job_id,
                "status": "approved",
            }
        except Exception as e:
            # Update status to failed in database (async)
            await db_manager.update_deployment_request_async(
                request_id, {"status": "failed"}
            )
            logger.error(f"Failed to start deployment: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Failed to start deployment: {str(e)}"
            )
    elif approval.action == "reject":
        # Delete the request from database instead of just marking as rejected
        try:
            await db_manager.delete_deployment_request_async(request_id)
            
            return {
                "message": "Request rejected and removed",
                "reason": approval.reason,
                "status": "deleted",
            }
        except Exception as e:
            logger.error(f"Failed to delete rejected request: {str(e)}")
            # Fallback to marking as rejected if deletion fails
            updates = {
                "status": "rejected",
                "rejection_reason": approval.reason,
            }
            await db_manager.update_deployment_request_async(
                request_id, updates
            )
            
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
