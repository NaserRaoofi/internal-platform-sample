"""
Redis Queue Worker - Background job processor
===========================================

Production-grade background worker for processing infrastructure jobs.
Handles async execution of Terraform operations.
"""

import os
import subprocess
import json
from datetime import datetime
from typing import Dict, Any, Optional
from redis import Redis
from rq import Worker, Queue
import logging

from infrastructure.config import get_settings
from domain.models import JobRequest, JobResult, JobStatus, JobLog, JobProgress

# Configure logging
settings = get_settings()
logging.basicConfig(
    level=getattr(logging, settings.log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class TerraformWorker:
    """Terraform operations worker"""
    
    def __init__(self):
        self.redis_conn = Redis(
            host=settings.REDIS_HOST,
            port=settings.REDIS_PORT,
            password=settings.REDIS_PASSWORD,
            decode_responses=True
        )
        self.terraform_dir = settings.TERRAFORM_DIR
    
    def update_job_status(self, job_id: str, status: JobStatus, 
                         error_message: Optional[str] = None,
                         terraform_output: Optional[Dict] = None) -> None:
        """Update job status in Redis"""
        try:
            result = JobResult(
                job_id=job_id,
                status=status,
                error_message=error_message,
                terraform_output=terraform_output,
                completed_at=datetime.utcnow() if status in [JobStatus.COMPLETED, JobStatus.FAILED] else None
            )
            self.redis_conn.set(
                f"job_result:{job_id}",
                result.json(),
                ex=settings.JOB_RESULT_TTL
            )
            
            # Publish WebSocket update
            self.redis_conn.publish(
                f"job_updates:{job_id}",
                json.dumps({
                    "type": "status_update",
                    "job_id": job_id,
                    "data": result.dict()
                })
            )
            
        except Exception as e:
            logger.error(f"Failed to update job status for {job_id}: {str(e)}")
    
    def add_job_log(self, job_id: str, message: str, level: str = "INFO", step: Optional[str] = None) -> None:
        """Add log entry to job"""
        try:
            log_entry = JobLog(
                message=message,
                level=level,
                step=step
            )
            
            # Store in Redis list
            self.redis_conn.lpush(
                f"job_logs:{job_id}",
                log_entry.json()
            )
            
            # Keep only last 1000 logs
            self.redis_conn.ltrim(f"job_logs:{job_id}", 0, 999)
            
            # Set expiry
            self.redis_conn.expire(f"job_logs:{job_id}", settings.JOB_RESULT_TTL)
            
            # Publish WebSocket update
            self.redis_conn.publish(
                f"job_updates:{job_id}",
                json.dumps({
                    "type": "log_update",
                    "job_id": job_id,
                    "data": log_entry.dict()
                })
            )
            
        except Exception as e:
            logger.error(f"Failed to add job log for {job_id}: {str(e)}")
    
    def run_terraform_command(self, cmd: list, cwd: str, job_id: str) -> tuple[bool, str, str]:
        """Execute terraform command with logging"""
        try:
            self.add_job_log(job_id, f"Executing: {' '.join(cmd)}", "INFO")
            
            process = subprocess.Popen(
                cmd,
                cwd=cwd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env={**os.environ, "TF_IN_AUTOMATION": "true"}
            )
            
            stdout, stderr = process.communicate()
            success = process.returncode == 0
            
            if stdout:
                self.add_job_log(job_id, f"STDOUT: {stdout}", "INFO")
            if stderr:
                level = "WARNING" if success else "ERROR"
                self.add_job_log(job_id, f"STDERR: {stderr}", level)
            
            return success, stdout, stderr
            
        except Exception as e:
            error_msg = f"Command execution failed: {str(e)}"
            self.add_job_log(job_id, error_msg, "ERROR")
            return False, "", error_msg
    
    def prepare_terraform_workspace(self, job_request: JobRequest) -> str:
        """Prepare Terraform workspace for job"""
        workspace_dir = f"{self.terraform_dir}/workspaces/{job_request.job_id}"
        template_dir = f"{self.terraform_dir}/templates/{job_request.resource_type.value}"
        
        try:
            # Create workspace directory
            os.makedirs(workspace_dir, exist_ok=True)
            
            # Copy template files
            import shutil
            if os.path.exists(template_dir):
                for item in os.listdir(template_dir):
                    s = os.path.join(template_dir, item)
                    d = os.path.join(workspace_dir, item)
                    if os.path.isdir(s):
                        shutil.copytree(s, d, dirs_exist_ok=True)
                    else:
                        shutil.copy2(s, d)
            
            # Generate terraform.tfvars
            tfvars_content = self.generate_tfvars(job_request)
            with open(f"{workspace_dir}/terraform.tfvars", "w") as f:
                f.write(tfvars_content)
            
            self.add_job_log(job_request.job_id, f"Workspace prepared: {workspace_dir}", "INFO")
            return workspace_dir
            
        except Exception as e:
            error_msg = f"Failed to prepare workspace: {str(e)}"
            self.add_job_log(job_request.job_id, error_msg, "ERROR")
            raise
    
    def generate_tfvars(self, job_request: JobRequest) -> str:
        """Generate terraform.tfvars content"""
        tfvars = {
            "resource_name": job_request.name,
            "environment": job_request.environment,
            "region": job_request.region,
            "tags": {
                **job_request.tags,
                "ManagedBy": "internal-platform",
                "JobId": job_request.job_id,
                "Environment": job_request.environment
            }
        }
        
        # Add resource-specific configuration
        tfvars.update(job_request.config)
        
        # Convert to HCL format
        lines = []
        for key, value in tfvars.items():
            if isinstance(value, dict):
                lines.append(f'{key} = {{')
                for k, v in value.items():
                    if isinstance(v, str):
                        lines.append(f'  {k} = "{v}"')
                    else:
                        lines.append(f'  {k} = {json.dumps(v)}')
                lines.append('}')
            elif isinstance(value, str):
                lines.append(f'{key} = "{value}"')
            else:
                lines.append(f'{key} = {json.dumps(value)}')
        
        return '\n'.join(lines)
    
    def process_infrastructure_job(self, job_request_json: str) -> str:
        """Main job processing function"""
        job_request = None
        job_id = "unknown"
        
        try:
            job_request = JobRequest.parse_raw(job_request_json)
            job_id = job_request.job_id
            
            self.add_job_log(job_id, f"Starting {job_request.action.value} job for {job_request.resource_type.value}", "INFO")
            self.update_job_status(job_id, JobStatus.RUNNING)
            
            # Prepare workspace
            workspace_dir = self.prepare_terraform_workspace(job_request)
            
            # Initialize Terraform
            success, stdout, stderr = self.run_terraform_command(
                ["terraform", "init"], workspace_dir, job_id
            )
            if not success:
                raise Exception(f"Terraform init failed: {stderr}")
            
            # Plan
            plan_file = f"{workspace_dir}/tfplan"
            if job_request.action.value == "destroy":
                cmd = ["terraform", "plan", "-destroy", f"-out={plan_file}"]
            else:
                cmd = ["terraform", "plan", f"-out={plan_file}"]
            
            success, stdout, stderr = self.run_terraform_command(cmd, workspace_dir, job_id)
            if not success:
                raise Exception(f"Terraform plan failed: {stderr}")
            
            # Apply
            if job_request.action.value == "destroy":
                cmd = ["terraform", "apply", "-auto-approve", plan_file]
            else:
                cmd = ["terraform", "apply", "-auto-approve", plan_file]
            
            success, stdout, stderr = self.run_terraform_command(cmd, workspace_dir, job_id)
            if not success:
                raise Exception(f"Terraform apply failed: {stderr}")
            
            # Get outputs
            success, output_json, stderr = self.run_terraform_command(
                ["terraform", "output", "-json"], workspace_dir, job_id
            )
            
            terraform_output = {}
            if success and output_json.strip():
                try:
                    terraform_output = json.loads(output_json)
                except json.JSONDecodeError:
                    self.add_job_log(job_id, "Failed to parse terraform outputs", "WARNING")
            
            # Mark as completed
            self.update_job_status(job_id, JobStatus.COMPLETED, terraform_output=terraform_output)
            self.add_job_log(job_id, f"Job completed successfully", "INFO")
            
            return f"Job {job_id} completed successfully"
            
        except Exception as e:
            error_msg = str(e)
            logger.error(f"Job {job_id} failed: {error_msg}")
            self.update_job_status(job_id, JobStatus.FAILED, error_message=error_msg)
            self.add_job_log(job_id, f"Job failed: {error_msg}", "ERROR")
            raise

def start_worker():
    """Start the RQ worker"""
    redis_conn = Redis(
        host=settings.REDIS_HOST,
        port=settings.REDIS_PORT,
        password=settings.REDIS_PASSWORD,
        decode_responses=True
    )
    
    queues = [
        Queue('default', connection=redis_conn),
        Queue('high', connection=redis_conn),
        Queue('low', connection=redis_conn)
    ]
    
    worker = Worker(queues, connection=redis_conn)
    logger.info("Starting RQ worker...")
    worker.work()

if __name__ == "__main__":
    start_worker()
