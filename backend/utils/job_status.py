"""
Job Status Management - Job lifecycle and status tracking
======================================================

Centralized job status management for infrastructure operations.
"""

import json
import time
from datetime import datetime, timedelta
from enum import Enum
from typing import Dict, Any, Optional, List
from pathlib import Path

class JobStatus(str, Enum):
    """Job status enumeration"""
    PENDING = "pending"
    QUEUED = "queued"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"

class JobManager:
    """Job status and lifecycle management"""
    
    def __init__(self, storage_path: str = "/tmp/job_storage"):
        self.storage_path = Path(storage_path)
        self.storage_path.mkdir(parents=True, exist_ok=True)
    
    def create_job(self, job_id: str, job_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create a new job record"""
        job_record = {
            "job_id": job_id,
            "status": JobStatus.PENDING.value,
            "created_at": datetime.utcnow().isoformat(),
            "updated_at": datetime.utcnow().isoformat(),
            "started_at": None,
            "completed_at": None,
            "logs": [],
            "error_message": None,
            "terraform_output": None,
            "metadata": job_data
        }
        
        self._save_job(job_id, job_record)
        return job_record
    
    def update_job_status(self, job_id: str, status: JobStatus, 
                         error_message: Optional[str] = None,
                         terraform_output: Optional[Dict] = None) -> Dict[str, Any]:
        """Update job status"""
        job_record = self.get_job(job_id)
        if not job_record:
            raise ValueError(f"Job {job_id} not found")
        
        job_record["status"] = status.value
        job_record["updated_at"] = datetime.utcnow().isoformat()
        
        if status == JobStatus.RUNNING and not job_record.get("started_at"):
            job_record["started_at"] = datetime.utcnow().isoformat()
        
        if status in [JobStatus.COMPLETED, JobStatus.FAILED, JobStatus.CANCELLED]:
            job_record["completed_at"] = datetime.utcnow().isoformat()
        
        if error_message:
            job_record["error_message"] = error_message
        
        if terraform_output:
            job_record["terraform_output"] = terraform_output
        
        self._save_job(job_id, job_record)
        return job_record
    
    def add_job_log(self, job_id: str, message: str, level: str = "INFO") -> None:
        """Add log entry to job"""
        job_record = self.get_job(job_id)
        if not job_record:
            raise ValueError(f"Job {job_id} not found")
        
        log_entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": level,
            "message": message
        }
        
        job_record["logs"].append(log_entry)
        job_record["updated_at"] = datetime.utcnow().isoformat()
        
        # Keep only last 1000 log entries
        if len(job_record["logs"]) > 1000:
            job_record["logs"] = job_record["logs"][-1000:]
        
        self._save_job(job_id, job_record)
    
    def get_job(self, job_id: str) -> Optional[Dict[str, Any]]:
        """Get job record by ID"""
        job_file = self.storage_path / f"{job_id}.json"
        
        if not job_file.exists():
            return None
        
        try:
            with open(job_file, 'r') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            return None
    
    def get_job_logs(self, job_id: str, limit: int = 100) -> List[Dict[str, Any]]:
        """Get job logs"""
        job_record = self.get_job(job_id)
        if not job_record:
            return []
        
        logs = job_record.get("logs", [])
        return logs[-limit:] if limit else logs
    
    def list_jobs(self, status_filter: Optional[JobStatus] = None, 
                  limit: int = 50) -> List[Dict[str, Any]]:
        """List jobs with optional status filter"""
        jobs = []
        
        for job_file in self.storage_path.glob("*.json"):
            try:
                with open(job_file, 'r') as f:
                    job_record = json.load(f)
                    
                if status_filter is None or job_record.get("status") == status_filter.value:
                    jobs.append(job_record)
                    
            except (json.JSONDecodeError, IOError):
                continue
        
        # Sort by created_at (newest first)
        jobs.sort(key=lambda x: x.get("created_at", ""), reverse=True)
        
        return jobs[:limit] if limit else jobs
    
    def get_active_jobs(self) -> List[Dict[str, Any]]:
        """Get currently active (running) jobs"""
        return self.list_jobs(status_filter=JobStatus.RUNNING)
    
    def cleanup_old_jobs(self, days: int = 30) -> int:
        """Clean up job records older than specified days"""
        cutoff_date = datetime.utcnow() - timedelta(days=days)
        cleaned_count = 0
        
        for job_file in self.storage_path.glob("*.json"):
            try:
                with open(job_file, 'r') as f:
                    job_record = json.load(f)
                
                created_at = datetime.fromisoformat(job_record.get("created_at", ""))
                
                if created_at < cutoff_date:
                    job_file.unlink()
                    cleaned_count += 1
                    
            except (json.JSONDecodeError, IOError, ValueError):
                continue
        
        return cleaned_count
    
    def _save_job(self, job_id: str, job_record: Dict[str, Any]) -> None:
        """Save job record to file"""
        job_file = self.storage_path / f"{job_id}.json"
        
        try:
            with open(job_file, 'w') as f:
                json.dump(job_record, f, indent=2, default=str)
        except IOError as e:
            raise RuntimeError(f"Failed to save job {job_id}: {e}")

# Global job manager instance
job_manager = JobManager()

# Utility functions
def create_job(job_id: str, job_data: Dict[str, Any]) -> Dict[str, Any]:
    """Create a new job"""
    return job_manager.create_job(job_id, job_data)

def update_job_status(job_id: str, status: JobStatus, **kwargs) -> Dict[str, Any]:
    """Update job status"""
    return job_manager.update_job_status(job_id, status, **kwargs)

def add_job_log(job_id: str, message: str, level: str = "INFO") -> None:
    """Add log to job"""
    job_manager.add_job_log(job_id, message, level)

def get_job_status(job_id: str) -> Optional[Dict[str, Any]]:
    """Get job status"""
    return job_manager.get_job(job_id)
