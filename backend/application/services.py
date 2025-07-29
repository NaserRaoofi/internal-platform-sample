"""
Application Services - Business logic and use cases
=================================================

Contains the main business logic and orchestration services.
"""

import logging
from typing import Dict, Any, Optional
from datetime import datetime

from domain.models import JobRequest, JobResult, JobStatus, JobAction, ResourceType
from domain.utils import generate_job_id, sanitize_resource_name, calculate_estimated_duration
from infrastructure.database import db

logger = logging.getLogger(__name__)

class InfrastructureService:
    """Main service for infrastructure operations"""
    
    def __init__(self):
        self.db = db
    
    async def create_infrastructure_job(
        self, 
        resource_type: ResourceType,
        name: str,
        action: JobAction,
        environment: str = "dev",
        region: str = "us-east-1",
        config: Dict[str, Any] = None,
        tags: Dict[str, str] = None
    ) -> JobRequest:
        """Create a new infrastructure job"""
        
        job_id = generate_job_id()
        sanitized_name = sanitize_resource_name(name)
        
        job_request = JobRequest(
            job_id=job_id,
            action=action,
            resource_type=resource_type,
            name=sanitized_name,
            environment=environment,
            region=region,
            config=config or {},
            tags=tags or {},
            created_at=datetime.utcnow()
        )
        
        # Create initial job result
        job_result = JobResult(
            job_id=job_id,
            status=JobStatus.QUEUED,
            started_at=datetime.utcnow()
        )
        
        # Store in database
        self.db.store_job_result(job_result)
        
        logger.info(f"Created infrastructure job {job_id} for {resource_type.value} '{name}'")
        return job_request
    
    async def get_job_status(self, job_id: str) -> Optional[JobResult]:
        """Get job status and details"""
        return self.db.get_job_result(job_id)
    
    async def get_job_logs(self, job_id: str) -> list:
        """Get job execution logs"""
        return self.db.get_job_logs(job_id)
    
    async def list_jobs(
        self, 
        limit: int = 50, 
        offset: int = 0,
        status_filter: Optional[JobStatus] = None
    ) -> list:
        """List jobs with pagination and filtering"""
        return self.db.list_jobs(limit, offset, status_filter)
    
    async def cancel_job(self, job_id: str) -> bool:
        """Cancel a running job"""
        job_result = self.db.get_job_result(job_id)
        
        if not job_result:
            return False
        
        if job_result.status in [JobStatus.COMPLETED, JobStatus.FAILED, JobStatus.CANCELLED]:
            return False
        
        # Update status to cancelled
        job_result.status = JobStatus.CANCELLED
        job_result.completed_at = datetime.utcnow()
        
        return self.db.store_job_result(job_result)
    
    async def get_system_stats(self) -> Dict[str, Any]:
        """Get system statistics"""
        job_counts = self.db.get_job_count_by_status()
        active_jobs = self.db.get_active_jobs()
        failed_jobs = self.db.get_failed_jobs(hours=24)
        
        return {
            "job_counts": job_counts,
            "active_jobs_count": len(active_jobs),
            "failed_jobs_last_24h": len(failed_jobs),
            "system_metrics": self.db.get_system_metrics()
        }

# Global service instance
infrastructure_service = InfrastructureService()
