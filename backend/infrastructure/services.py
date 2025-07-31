"""
Database Services - SQLite + Redis Hybrid Operations
========================================================

Service layer that combines SQLite for persistent data
and Redis for caching and real-time operations.
"""

import json
import logging
from datetime import datetime
from typing import Any, Dict, List, Optional

from sqlalchemy import select, update

from infrastructure.database import redis_cache, sqlite_manager
from infrastructure.models import (
    AuditLog,
    InfrastructureJob,
    InfrastructureResource,
    JobLog,
    SystemMetrics,
    User,
)

logger = logging.getLogger(__name__)


class UserService:
    """User management with SQLite storage"""

    @staticmethod
    def create_user(
        username: str,
        email: str,
        role: str,
        password_hash: Optional[str] = None,
    ) -> User:
        """Create a new user"""
        with sqlite_manager.get_session() as session:
            user = User(
                username=username,
                email=email,
                role=role,
                password_hash=password_hash,
            )
            session.add(user)
            session.commit()
            session.refresh(user)
            return user

    @staticmethod
    def get_user_by_username(username: str) -> Optional[User]:
        """Get user by username"""
        with sqlite_manager.get_session() as session:
            result = session.execute(
                select(User).where(
                    User.username == username, User.is_active.is_(True)
                )
            )
            return result.scalar_one_or_none()

    @staticmethod
    def get_user_by_id(user_id: int) -> Optional[User]:
        """Get user by ID"""
        with sqlite_manager.get_session() as session:
            result = session.execute(
                select(User).where(
                    User.id == user_id, User.is_active.is_(True)
                )
            )
            return result.scalar_one_or_none()

    @staticmethod
    def update_last_login(user_id: int) -> bool:
        """Update user's last login timestamp"""
        try:
            with sqlite_manager.get_session() as session:
                session.execute(
                    update(User)
                    .where(User.id == user_id)
                    .values(last_login=datetime.utcnow())
                )
                session.commit()
                return True
        except Exception as e:
            logger.error(
                f"Failed to update last login for user {user_id}: {str(e)}"
            )
            return False


class JobService:
    """Job management with SQLite + Redis hybrid storage"""

    @staticmethod
    def create_job(
        user_id: int,
        job_id: str,
        resource_type: str,
        resource_name: str,
        environment: str = "dev",
        region: str = "us-east-1",
        config: Optional[Dict] = None,
    ) -> InfrastructureJob:
        """Create new job in SQLite"""
        with sqlite_manager.get_session() as session:
            job = InfrastructureJob(
                job_id=job_id,
                user_id=user_id,
                resource_type=resource_type,
                resource_name=resource_name,
                environment=environment,
                region=region,
                status="queued",
                config=config or {},
            )
            session.add(job)
            session.commit()
            session.refresh(job)

            # Cache active job in Redis for real-time access
            job_data = {
                "job_id": str(job.job_id),
                "status": job.status,
                "resource_type": job.resource_type,
                "resource_name": job.resource_name,
                "created_at": job.created_at.isoformat(),
            }
            redis_cache.cache_job_progress(str(job.job_id), job_data)

            return job

    @staticmethod
    def update_job_status(
        job_id: str,
        status: str,
        error_message: Optional[str] = None,
        terraform_output: Optional[Dict] = None,
        started_at: Optional[datetime] = None,
        completed_at: Optional[datetime] = None,
    ) -> bool:
        """Update job status in both SQLite and Redis cache"""
        try:
            with sqlite_manager.get_session() as session:
                # Update in SQLite
                update_data: Dict[str, Any] = {"status": status}
                if error_message:
                    update_data["error_message"] = error_message
                if terraform_output:
                    update_data["terraform_output"] = terraform_output
                if started_at:
                    update_data["started_at"] = started_at
                if completed_at:
                    update_data["completed_at"] = completed_at

                session.execute(
                    update(InfrastructureJob)
                    .where(InfrastructureJob.job_id == job_id)
                    .values(**update_data)
                )
                session.commit()

                # Update Redis cache for real-time access
                cached_job = redis_cache.get_job_progress(job_id)
                if cached_job:
                    cached_job.update(
                        {
                            "status": status,
                            "error_message": error_message,
                            "updated_at": datetime.utcnow().isoformat(),
                        }
                    )
                    redis_cache.cache_job_progress(job_id, cached_job)

                return True
        except Exception as e:
            logger.error(f"Failed to update job status {job_id}: {str(e)}")
            return False

    @staticmethod
    def get_job_by_id(job_id: str) -> Optional[InfrastructureJob]:
        """Get job by ID from SQLite"""
        with sqlite_manager.get_session() as session:
            result = session.execute(
                select(InfrastructureJob).where(
                    InfrastructureJob.job_id == job_id
                )
            )
            return result.scalar_one_or_none()

    @staticmethod
    def list_user_jobs(
        user_id: int,
        limit: int = 50,
        offset: int = 0,
        status_filter: Optional[str] = None,
    ) -> List[InfrastructureJob]:
        """List user's jobs with pagination"""
        with sqlite_manager.get_session() as session:
            query = select(InfrastructureJob).where(
                InfrastructureJob.user_id == user_id
            )

            if status_filter:
                query = query.where(InfrastructureJob.status == status_filter)

            query = query.order_by(InfrastructureJob.created_at.desc())
            query = query.offset(offset).limit(limit)

            result = session.execute(query)
            return list(result.scalars().all())

    @staticmethod
    def add_job_log(
        job_id: str,
        message: str,
        level: str = "INFO",
        step: Optional[str] = None,
    ) -> bool:
        """Add job log to SQLite"""
        try:
            with sqlite_manager.get_session() as session:
                # Store in SQLite for persistence
                job_log = JobLog(
                    job_id=job_id,
                    message=message,
                    level=level,
                    step=step,
                )
                session.add(job_log)
                session.commit()

                # Cache in Redis for real-time streaming
                log_data = {
                    "message": message,
                    "level": level,
                    "step": step,
                    "created_at": datetime.utcnow().isoformat(),
                }
                redis_cache.cache_set(f"job_logs:{job_id}", log_data)

                return True
        except Exception as e:
            logger.error(f"Failed to add job log {job_id}: {str(e)}")
            return False


class ResourceService:
    """Infrastructure resource lifecycle management"""

    @staticmethod
    def create_resource(
        job_id: str,
        user_id: int,
        resource_type: str,
        resource_name: str,
        aws_resource_id: str,
        aws_arn: Optional[str] = None,
        region: str = "us-east-1",
        environment: str = "dev",
        terraform_outputs: Optional[Dict] = None,
        resource_config: Optional[Dict] = None,
    ) -> InfrastructureResource:
        """Create resource record when infrastructure is created"""
        with sqlite_manager.get_session() as session:
            resource = InfrastructureResource(
                resource_id=aws_resource_id,
                job_id=job_id,
                user_id=user_id,
                resource_type=resource_type,
                resource_name=resource_name,
                aws_arn=aws_arn,
                region=region,
                environment=environment,
                status="active",
                resource_config=resource_config or {},
                resource_outputs=terraform_outputs or {},
            )
            session.add(resource)
            session.commit()
            session.refresh(resource)

            # Cache active resource for quick access
            resource_data = {
                "resource_id": resource.resource_id,
                "resource_name": resource.resource_name,
                "resource_type": resource.resource_type,
                "status": "active",
                "created_at": resource.created_at.isoformat(),
            }
            redis_cache.cache_set(
                f"resource:{resource.resource_id}", resource_data
            )

            return resource

    @staticmethod
    def destroy_resource(resource_id: str) -> bool:
        """Mark resource as destroyed when infrastructure is torn down"""
        try:
            with sqlite_manager.get_session() as session:
                session.execute(
                    update(InfrastructureResource)
                    .where(InfrastructureResource.resource_id == resource_id)
                    .values(
                        status="destroyed",
                        destroyed_at=datetime.utcnow()
                    )
                )
                session.commit()

                # Remove from Redis cache
                redis_cache.cache_set(f"resource:{resource_id}", None)

                return True
        except Exception as e:
            logger.error(f"Failed to destroy resource {resource_id}: {str(e)}")
            return False

    @staticmethod
    def get_user_resources(
        user_id: int,
        status: str = "active",
        resource_type: Optional[str] = None,
    ) -> List[InfrastructureResource]:
        """Get user's active resources"""
        with sqlite_manager.get_session() as session:
            query = select(InfrastructureResource).where(
                InfrastructureResource.user_id == user_id,
                InfrastructureResource.status == status
            )

            if resource_type:
                query = query.where(
                    InfrastructureResource.resource_type == resource_type
                )

            query = query.order_by(InfrastructureResource.created_at.desc())
            result = session.execute(query)
            return list(result.scalars().all())

    @staticmethod
    def get_resource_by_id(
        resource_id: str
    ) -> Optional[InfrastructureResource]:
        """Get resource by AWS resource ID"""
        with sqlite_manager.get_session() as session:
            result = session.execute(
                select(InfrastructureResource).where(
                    InfrastructureResource.resource_id == resource_id
                )
            )
            return result.scalar_one_or_none()

    @staticmethod
    def get_resource_by_name(
        user_id: int, resource_name: str, environment: str = "dev"
    ) -> Optional[InfrastructureResource]:
        """Get resource by name and environment"""
        with sqlite_manager.get_session() as session:
            result = session.execute(
                select(InfrastructureResource).where(
                    InfrastructureResource.user_id == user_id,
                    InfrastructureResource.resource_name == resource_name,
                    InfrastructureResource.environment == environment,
                    InfrastructureResource.status == "active"
                )
            )
            return result.scalar_one_or_none()


class AuditService:
    """Audit logging with SQLite storage"""

    @staticmethod
    def log_action(
        user_id: int,
        action: str,
        resource_type: Optional[str] = None,
        resource_id: Optional[str] = None,
        details: Optional[Dict] = None,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
        success: bool = True,
        error_message: Optional[str] = None,
    ) -> bool:
        """Log user action for audit trail"""
        try:
            with sqlite_manager.get_session() as session:
                audit_log = AuditLog(
                    user_id=user_id,
                    action=action,
                    resource_type=resource_type,
                    resource_id=resource_id,
                    details=details or {},
                    ip_address=ip_address,
                    user_agent=user_agent,
                    success=success,
                    error_message=error_message,
                )
                session.add(audit_log)
                session.commit()
                return True
        except Exception as e:
            logger.error(f"Failed to log audit action: {str(e)}")
            return False


class MetricsService:
    """System metrics with SQLite storage + Redis caching"""

    @staticmethod
    def record_metrics(
        active_jobs: int,
        queued_jobs: int,
        completed_jobs_today: int,
        failed_jobs_today: int,
        redis_memory_usage: Optional[int] = None,
        redis_connected_clients: Optional[int] = None,
        queue_size: Optional[int] = None,
        avg_job_duration: Optional[int] = None,
    ) -> bool:
        """Record system metrics"""
        try:
            with sqlite_manager.get_session() as session:
                # Store in SQLite for historical data
                metrics = SystemMetrics(
                    active_jobs=active_jobs,
                    queued_jobs=queued_jobs,
                    completed_jobs_today=completed_jobs_today,
                    failed_jobs_today=failed_jobs_today,
                    redis_memory_usage=redis_memory_usage,
                    redis_connected_clients=redis_connected_clients,
                    queue_size=queue_size,
                    avg_job_duration=avg_job_duration,
                )
                session.add(metrics)
                session.commit()

                # Cache current metrics in Redis
                metrics_data = {
                    "active_jobs": active_jobs,
                    "queued_jobs": queued_jobs,
                    "completed_jobs_today": completed_jobs_today,
                    "failed_jobs_today": failed_jobs_today,
                    "redis_memory_usage": redis_memory_usage,
                    "redis_connected_clients": redis_connected_clients,
                    "queue_size": queue_size,
                    "avg_job_duration": avg_job_duration,
                    "recorded_at": datetime.utcnow().isoformat(),
                }
                redis_cache.cache_set("system_metrics", metrics_data)

                return True
        except Exception as e:
            logger.error(f"Failed to record metrics: {str(e)}")
            return False

    @staticmethod
    def get_current_metrics() -> Optional[Dict[str, Any]]:
        """Get current metrics (from Redis cache first, then SQLite)"""
        # Try Redis cache first
        cached_metrics = redis_cache.cache_get("system_metrics")
        if cached_metrics:
            try:
                return json.loads(cached_metrics)
            except (json.JSONDecodeError, TypeError):
                pass

        # Fallback to SQLite
        try:
            with sqlite_manager.get_session() as session:
                result = session.execute(
                    select(SystemMetrics)
                    .order_by(SystemMetrics.recorded_at.desc())
                    .limit(1)
                )
                latest_metrics = result.scalar_one_or_none()

                if latest_metrics:
                    return {
                        "active_jobs": latest_metrics.active_jobs,
                        "queued_jobs": latest_metrics.queued_jobs,
                        "completed_jobs_today": (
                            latest_metrics.completed_jobs_today
                        ),
                        "failed_jobs_today": latest_metrics.failed_jobs_today,
                        "recorded_at": latest_metrics.recorded_at.isoformat(),
                    }
                return None
        except Exception as e:
            logger.error(f"Failed to get current metrics: {str(e)}")
            return None


# Service instances
user_service = UserService()
job_service = JobService()
resource_service = ResourceService()
audit_service = AuditService()
metrics_service = MetricsService()
