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
    """Create infrastructure resources"""
    try:
        job_id = str(uuid.uuid4())
        created_at = datetime.utcnow().isoformat()

        # Use infrastructure service with Redis queue
        await infrastructure_service.create_infrastructure(
            job_id=job_id,
            resource_type=request.resource_type,
            name=request.name,
            environment=request.environment,
            region=request.region,
            config=request.config,
            tags=request.tags,
        )

        return JobResponse(
            job_id=job_id,
            status="queued",
            message=f"Infrastructure creation queued for "
                   f"{request.resource_type}",
            created_at=created_at,
            estimated_duration="5-15 minutes",
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
