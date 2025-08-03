"""
Application Services - Business logic and use cases
=================================================

Contains the main business logic and orchestration services.
"""

import logging
from datetime import datetime
from typing import Any, Dict, Optional

from rq import Queue
from utils.job_status import (
    create_job,
    update_job_status,
    JobStatus as UtilsJobStatus,
    add_job_log
)
from infrastructure.database import RedisConnectionManager

logger = logging.getLogger(__name__)

# Redis connection manager with pooling
redis_manager = RedisConnectionManager()
job_queue = Queue("default", connection=redis_manager.get_rq_connection())


class InfrastructureService:
    """Main service for infrastructure operations"""

    def __init__(self):
        pass

    async def create_infrastructure(
        self,
        job_id: str,
        resource_type: str,
        name: str,
        environment: str = "dev",
        region: str = "us-east-1",
        config: Optional[Dict[str, Any]] = None,
        tags: Optional[Dict[str, str]] = None,
    ) -> Dict[str, Any]:
        """Create infrastructure resources"""

        logger.info(f"Creating {resource_type} infrastructure: {name}")

        # Prepare job data
        job_data = {
            "job_id": job_id,
            "action": "create",
            "resource_type": resource_type,
            "name": name,
            "environment": environment,
            "region": region,
            "config": config or {},
            "tags": tags or {},
            "created_at": datetime.utcnow().isoformat(),
        }

        # Create job in the job status system
        create_job(job_id, job_data)
        add_job_log(job_id, f"Started {resource_type} creation process")

        # Queue the job in Redis
        try:
            from application.worker import process_infrastructure_job

            job_queue.enqueue(
                process_infrastructure_job,
                job_data,
                job_id=job_id,
                job_timeout="30m"
            )
            logger.info(f"Job {job_id} queued successfully")
            add_job_log(job_id, "Job queued in Redis for processing")

            # Update job status to queued
            update_job_status(job_id, UtilsJobStatus.RUNNING)

            # Special handling for S3 bucket creation (sirwan-v23 test case)
            if resource_type.lower() == "s3":
                bucket_name = f"{name}-{environment}"
                return {
                    "job_id": job_id,
                    "status": "queued",
                    "resource_type": "s3",
                    "name": name,
                    "environment": environment,
                    "region": region,
                    "bucket_name": bucket_name,
                    "message": f"S3 bucket '{bucket_name}' creation queued",
                    "terraform_template": "s3-bucket",
                }

            # Default response for other resource types
            return {
                "job_id": job_id,
                "status": "queued",
                "resource_type": resource_type,
                "name": name,
                "environment": environment,
                "region": region,
            }

        except Exception as e:
            logger.error(f"Failed to queue job {job_id}: {str(e)}")
            update_job_status(job_id, UtilsJobStatus.FAILED, error=str(e))
            add_job_log(job_id, f"Failed to queue job: {str(e)}")
            raise Exception(f"Failed to queue infrastructure job: {str(e)}")

    async def destroy_infrastructure(
        self,
        job_id: str,
        resource_type: str,
        name: str,
        environment: str = "dev",
        region: str = "us-east-1",
    ) -> Dict[str, Any]:
        """Destroy infrastructure resources"""

        logger.info(f"Destroying {resource_type} infrastructure: {name}")

        # Prepare job data
        job_data = {
            "job_id": job_id,
            "action": "destroy",
            "resource_type": resource_type,
            "name": name,
            "environment": environment,
            "region": region,
            "created_at": datetime.utcnow().isoformat(),
        }

        # Create job in the job status system
        create_job(job_id, job_data)
        add_job_log(job_id, f"Started {resource_type} destruction process")

        try:
            from application.worker import process_infrastructure_job

            job_queue.enqueue(
                process_infrastructure_job,
                job_data,
                job_id=job_id,
                job_timeout="30m"
            )
            logger.info(f"Destroy job {job_id} queued successfully")
            add_job_log(job_id, "Destroy job queued in Redis for processing")

            # Update job status to running
            update_job_status(job_id, UtilsJobStatus.RUNNING)

            return {
                "job_id": job_id,
                "status": "queued",
                "action": "destroy",
                "resource_type": resource_type,
                "name": name,
                "environment": environment,
                "region": region,
            }

        except Exception as e:
            logger.error(f"Failed to queue destroy job {job_id}: {str(e)}")
            update_job_status(job_id, UtilsJobStatus.FAILED, error=str(e))
            add_job_log(job_id, f"Failed to queue destroy job: {str(e)}")
            raise Exception(
                f"Failed to queue infrastructure destroy job: {str(e)}"
            )


# Create service instance
infrastructure_service = InfrastructureService()
