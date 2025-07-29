"""
Database Layer - Redis and data storage utilities
===============================================

Production-grade database abstraction layer for job management.
"""

import json
from datetime import datetime, timedelta
from typing import List, Optional, Dict, Any
from redis import Redis
import logging

from infrastructure.config import get_settings
from domain.models import JobResult, JobStatus, JobLog

logger = logging.getLogger(__name__)
settings = get_settings()

class DatabaseManager:
    """Database operations manager using Redis"""
    
    def __init__(self):
        self.redis = Redis(
            host=settings.redis_host,
            port=settings.redis_port,
            password=settings.redis_password,
            decode_responses=True,
            socket_connect_timeout=5,
            socket_timeout=5,
            retry_on_timeout=True
        )
    
    def health_check(self) -> bool:
        """Check database connectivity"""
        try:
            result = self.redis.ping()
            return bool(result)
        except Exception as e:
            logger.error(f"Database health check failed: {str(e)}")
            return False
    
    def store_job_result(self, job_result: JobResult) -> bool:
        """Store job result in database"""
        try:
            key = f"job_result:{job_result.job_id}"
            value = job_result.json()
            
            # Store with TTL
            self.redis.setex(key, settings.job_result_ttl, value)
            
            # Add to job index for listing
            self.redis.zadd(
                "jobs_index",
                {job_result.job_id: datetime.utcnow().timestamp()}
            )
            
            return True
        except Exception as e:
            logger.error(f"Failed to store job result {job_result.job_id}: {str(e)}")
            return False
    
    def get_job_result(self, job_id: str) -> Optional[JobResult]:
        """Retrieve job result from database"""
        try:
            key = f"job_result:{job_id}"
            data = self.redis.get(key)
            
            if data and isinstance(data, str):
                return JobResult.model_validate_json(data)
            return None
        except Exception as e:
            logger.error(f"Failed to get job result {job_id}: {str(e)}")
            return None
    
    def get_job_logs(self, job_id: str, limit: int = 100) -> List[JobLog]:
        """Retrieve job logs from database"""
        try:
            key = f"job_logs:{job_id}"
            logs_data = self.redis.lrange(key, 0, limit - 1)
            
            logs = []
            if isinstance(logs_data, list):
                for log_data in logs_data:
                    try:
                        if isinstance(log_data, str):
                            log = JobLog.model_validate_json(log_data)
                            logs.append(log)
                    except Exception as e:
                        logger.warning(f"Failed to parse log entry: {str(e)}")
            
            return logs
        except Exception as e:
            logger.error(f"Failed to get job logs {job_id}: {str(e)}")
            return []
    
    def list_jobs(self, limit: int = 50, offset: int = 0, 
                  status_filter: Optional[JobStatus] = None) -> List[JobResult]:
        """List jobs with pagination and filtering"""
        try:
            # Get job IDs from index (newest first)
            job_ids = self.redis.zrevrange("jobs_index", offset, offset + limit - 1)
            
            jobs = []
            if isinstance(job_ids, list):
                for job_id in job_ids:
                    if isinstance(job_id, str):
                        job_result = self.get_job_result(job_id)
                        if job_result:
                            if status_filter is None or job_result.status == status_filter:
                                jobs.append(job_result)
            
            return jobs
        except Exception as e:
            logger.error(f"Failed to list jobs: {str(e)}")
            return []
    
    def get_job_count_by_status(self) -> Dict[str, int]:
        """Get job counts grouped by status"""
        try:
            counts = {status.value: 0 for status in JobStatus}
            
            # Get all job IDs
            job_ids = self.redis.zrange("jobs_index", 0, -1)
            
            if isinstance(job_ids, list):
                for job_id in job_ids:
                    if isinstance(job_id, str):
                        job_result = self.get_job_result(job_id)
                        if job_result:
                            counts[job_result.status.value] += 1
            
            return counts
        except Exception as e:
            logger.error(f"Failed to get job counts: {str(e)}")
            return {status.value: 0 for status in JobStatus}
    
    def cleanup_expired_jobs(self) -> int:
        """Clean up expired job data"""
        try:
            cutoff_time = datetime.utcnow() - timedelta(seconds=settings.job_result_ttl)
            cutoff_timestamp = cutoff_time.timestamp()
            
            # Get expired job IDs
            expired_job_ids = self.redis.zrangebyscore(
                "jobs_index", "-inf", cutoff_timestamp
            )
            
            cleanup_count = 0
            if isinstance(expired_job_ids, list) and expired_job_ids:
                # Remove from index
                self.redis.zremrangebyscore("jobs_index", "-inf", cutoff_timestamp)
                
                # Clean up individual job data (if not already expired by Redis TTL)
                for job_id in expired_job_ids:
                    if isinstance(job_id, str):
                        self.redis.delete(f"job_result:{job_id}")
                        self.redis.delete(f"job_logs:{job_id}")
                        cleanup_count += 1
            
            logger.info(f"Cleaned up {cleanup_count} expired jobs")
            return cleanup_count
            
        except Exception as e:
            logger.error(f"Failed to cleanup expired jobs: {str(e)}")
            return 0
    
    def get_active_jobs(self) -> List[JobResult]:
        """Get currently running jobs"""
        return self.list_jobs(limit=100, status_filter=JobStatus.RUNNING)
    
    def get_failed_jobs(self, hours: int = 24) -> List[JobResult]:
        """Get failed jobs from the last N hours"""
        try:
            all_jobs = self.list_jobs(limit=200)
            cutoff_time = datetime.utcnow() - timedelta(hours=hours)
            
            failed_jobs = []
            for job in all_jobs:
                if (job.status == JobStatus.FAILED and 
                    job.completed_at and 
                    job.completed_at >= cutoff_time):
                    failed_jobs.append(job)
            
            return failed_jobs
        except Exception as e:
            logger.error(f"Failed to get failed jobs: {str(e)}")
            return []
    
    def store_system_metrics(self, metrics: Dict[str, Any]) -> bool:
        """Store system metrics"""
        try:
            key = f"metrics:{datetime.utcnow().strftime('%Y%m%d_%H')}"
            
            # Store hourly metrics
            self.redis.hset(key, mapping=metrics)
            self.redis.expire(key, 7 * 24 * 3600)  # Keep for 7 days
            
            # Also store current metrics
            self.redis.hset("metrics:current", mapping=metrics)
            
            return True
        except Exception as e:
            logger.error(f"Failed to store metrics: {str(e)}")
            return False
    
    def get_system_metrics(self) -> Dict[str, Any]:
        """Get current system metrics"""
        try:
            metrics = self.redis.hgetall("metrics:current")
            
            # Convert string values back to appropriate types
            converted_metrics = {}
            if isinstance(metrics, dict):
                for key, value in metrics.items():
                    try:
                        # Try to convert to int/float
                        if isinstance(value, str):
                            if '.' in value:
                                converted_metrics[key] = float(value)
                            else:
                                converted_metrics[key] = int(value)
                        else:
                            converted_metrics[key] = value
                    except ValueError:
                        converted_metrics[key] = value
            
            return converted_metrics
        except Exception as e:
            logger.error(f"Failed to get metrics: {str(e)}")
            return {}

# Global database instance
db = DatabaseManager()
