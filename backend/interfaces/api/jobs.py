"""
Job Management API Routes
========================
"""
from fastapi import APIRouter, HTTPException
from typing import Optional
import logging

from infrastructure.database import db
from application.services import infrastructure_service
from domain.models import JobStatus

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1", tags=["jobs"])

@router.get("/job-status/{job_id}")
async def get_job_status(job_id: str):
    """Get job status and details"""
    try:
        job_result = db.get_job_result(job_id)
        if not job_result:
            raise HTTPException(status_code=404, detail="Job not found")
        return job_result
    except Exception as e:
        logger.error(f"Failed to get job status: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/job-logs/{job_id}")
async def get_job_logs(job_id: str, limit: int = 100):
    """Get job execution logs"""
    try:
        return db.get_job_logs(job_id, limit)
    except Exception as e:
        logger.error(f"Failed to get job logs: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/jobs")
async def list_jobs(
    status: Optional[str] = None,
    resource_type: Optional[str] = None,
    limit: int = 50,
    offset: int = 0
):
    """List jobs with optional filtering"""
    try:
        status_filter = JobStatus(status) if status else None
        return db.list_jobs(limit, offset, status_filter)
    except Exception as e:
        logger.error(f"Failed to list jobs: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
