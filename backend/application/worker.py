"""
Redis Queue Worker - Background job processor
===========================================

Production-grade background worker for processing infrastructure jobs.
Handles async execution of Terraform operations.
"""
# flake8: noqa: E501

import json
import logging
import os
import subprocess
from datetime import datetime
from typing import Any, Dict, Optional

from redis import Redis
from rq import Queue, Worker

from domain.models import JobLog, JobRequest, JobResult, JobStatus
from infrastructure.config import get_settings
from infrastructure.database import RedisConnectionManager
from utils.job_status import (
    update_job_status, 
    add_job_log, 
    JobStatus as UtilsJobStatus
)

# Configure logging
settings = get_settings()
redis_manager = RedisConnectionManager()
logging.basicConfig(
    level=getattr(logging, settings.log_level),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


class TerraformWorker:
    """Terraform operations worker"""

    def __init__(self):
        self.redis_manager = RedisConnectionManager()
        self.terraform_dir = settings.terraform_dir

    def run_terraform_command(
        self, cmd: list, cwd: str, job_id: str
    ) -> tuple[bool, str, str]:
        """Execute terraform command with logging"""
        try:
            add_job_log(job_id, f"Executing: {' '.join(cmd)}", "INFO")

            process = subprocess.Popen(
                cmd,
                cwd=cwd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env={**os.environ, "TF_IN_AUTOMATION": "true"},
            )

            stdout, stderr = process.communicate()
            success = process.returncode == 0

            if stdout:
                add_job_log(job_id, f"STDOUT: {stdout}", "INFO")
            if stderr:
                level = "WARNING" if success else "ERROR"
                add_job_log(job_id, f"STDERR: {stderr}", level)

            return success, stdout, stderr

        except Exception as e:
            error_msg = f"Command execution failed: {str(e)}"
            add_job_log(job_id, error_msg, "ERROR")
            return False, "", error_msg

    def prepare_terraform_workspace(self, job_request: JobRequest) -> str:
        """Prepare Terraform workspace for job"""
        workspace_dir = f"{self.terraform_dir}/workspaces/{job_request.job_id}"

        # Determine template directory based on config or resource type
        template_name = self.get_template_name(job_request)
        template_dir = f"{self.terraform_dir}/templates/{template_name}"

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

                add_job_log(
                    job_request.job_id, f"Using template: {template_name}", "INFO"
                )
            else:
                # Fallback: try to find a suitable template
                fallback_template = self.find_fallback_template(
                    job_request.resource_type.value
                )
                if fallback_template:
                    template_dir = f"{self.terraform_dir}/templates/{fallback_template}"
                    if os.path.exists(template_dir):
                        for item in os.listdir(template_dir):
                            s = os.path.join(template_dir, item)
                            d = os.path.join(workspace_dir, item)
                            if os.path.isdir(s):
                                shutil.copytree(s, d, dirs_exist_ok=True)
                            else:
                                shutil.copy2(s, d)
                        add_job_log(
                            job_request.job_id,
                            f"Using fallback template: {fallback_template}",
                            "WARNING",
                        )
                    else:
                        raise Exception(
                            f"No suitable template found for {job_request.resource_type.value}"
                        )
                else:
                    raise Exception(f"Template directory not found: {template_dir}")

            # Generate terraform.tfvars
            tfvars_content = self.generate_tfvars(job_request)
            with open(f"{workspace_dir}/terraform.tfvars", "w") as f:
                f.write(tfvars_content)

            add_job_log(
                job_request.job_id, f"Workspace prepared: {workspace_dir}", "INFO"
            )
            return workspace_dir

        except Exception as e:
            error_msg = f"Failed to prepare workspace: {str(e)}"
            add_job_log(job_request.job_id, error_msg, "ERROR")
            raise

    def get_template_name(self, job_request: JobRequest) -> str:
        """Determine which template to use based on job request"""
        # Check if template is explicitly specified in config
        if "template" in job_request.config:
            return job_request.config["template"]

        # Check if template is specified in tags
        if "Template" in job_request.tags:
            return job_request.tags["Template"]

        # Default mapping for backward compatibility
        template_mapping = {
            "web_app": "web-app-simple",
            "api_service": "api-simple",
            "s3": "sirwan-test",  # Default S3 to sirwan-test template
            "ec2": "api-simple",  # Default EC2 to api-simple template
            "rds": "api-simple",  # Default RDS to api-simple template
            "vpc": "web-app-simple",  # Default VPC to web-app-simple template
        }

        return template_mapping.get(
            job_request.resource_type.value, job_request.resource_type.value
        )

    def find_fallback_template(self, resource_type: str) -> Optional[str]:
        """Find a fallback template if the primary one doesn't exist"""
        import os

        templates_dir = f"{self.terraform_dir}/templates"

        if not os.path.exists(templates_dir):
            return None

        available_templates = [
            d
            for d in os.listdir(templates_dir)
            if os.path.isdir(os.path.join(templates_dir, d))
        ]

        # Fallback logic based on resource type
        fallback_mapping = {
            "s3": ["sirwan-test", "web-app-simple"],
            "ec2": ["api-simple", "web-app-simple"],
            "web_app": ["web-app-simple"],
            "api_service": ["api-simple"],
            "rds": ["api-simple", "web-app-simple"],
            "vpc": ["web-app-simple"],
        }

        for fallback in fallback_mapping.get(resource_type, []):
            if fallback in available_templates:
                return fallback

        # Last resort: return first available template
        if available_templates:
            return available_templates[0]

        return None

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
                "Environment": job_request.environment,
            },
        }

        # Add resource-specific variables based on resource type
        if job_request.resource_type.value == "s3":
            tfvars["bucket_name"] = job_request.name

        # Add resource-specific configuration
        tfvars.update(job_request.config)

        # Convert to HCL format
        lines = []
        for key, value in tfvars.items():
            if isinstance(value, dict):
                lines.append(f"{key} = {{")
                for k, v in value.items():
                    if isinstance(v, str):
                        lines.append(f'  {k} = "{v}"')
                    else:
                        lines.append(f"  {k} = {json.dumps(v)}")
                lines.append("}")
            elif isinstance(value, str):
                lines.append(f'{key} = "{value}"')
            else:
                lines.append(f"{key} = {json.dumps(value)}")

        return "\n".join(lines)

    def process_infrastructure_job(self, job_request_json: str) -> str:
        """Main job processing function"""
        job_request = None
        job_id = "unknown"

        try:
            job_request = JobRequest.parse_raw(job_request_json)
            job_id = job_request.job_id

            add_job_log(
                job_id,
                f"Starting {job_request.action.value} job for {job_request.resource_type.value}",
                "INFO",
            )
            update_job_status(job_id, UtilsJobStatus.RUNNING)

            # Prepare workspace
            workspace_dir = self.prepare_terraform_workspace(job_request)

            # Initialize Terraform
            success, stdout, stderr = self.run_terraform_command(
                ["terraform", "init"], workspace_dir, job_id
            )
            if not success:
                raise Exception(f"Terraform init failed: {stderr}")

            # Plan
            plan_file = "tfplan"  # Use relative path since we're in workspace_dir
            if job_request.action.value == "destroy":
                cmd = ["terraform", "plan", "-destroy", f"-out={plan_file}"]
            else:
                cmd = ["terraform", "plan", f"-out={plan_file}"]

            success, stdout, stderr = self.run_terraform_command(
                cmd, workspace_dir, job_id
            )
            if not success:
                raise Exception(f"Terraform plan failed: {stderr}")

            # Apply
            if job_request.action.value == "destroy":
                cmd = ["terraform", "apply", "-auto-approve", plan_file]
            else:
                cmd = ["terraform", "apply", "-auto-approve", plan_file]

            success, stdout, stderr = self.run_terraform_command(
                cmd, workspace_dir, job_id
            )
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
                    add_job_log(
                        job_id, "Failed to parse terraform outputs", "WARNING"
                    )

            # Mark as completed
            update_job_status(
                job_id, UtilsJobStatus.COMPLETED, terraform_output=terraform_output
            )
            add_job_log(job_id, "Job completed successfully", "INFO")

            return f"Job {job_id} completed successfully"

        except Exception as e:
            error_msg = str(e)
            logger.error(f"Job {job_id} failed: {error_msg}")
            update_job_status(job_id, UtilsJobStatus.FAILED, error_message=error_msg)
            add_job_log(job_id, f"Job failed: {error_msg}", "ERROR")
            return f"Job {job_id} failed: {error_msg}"


# Standalone function for RQ to call
def process_infrastructure_job(job_data: Dict[str, Any]) -> str:
    """Standalone function that RQ can call to process infrastructure jobs"""
    try:
        # Convert job_data dict to JobRequest JSON string
        created_at = job_data.get("created_at")
        if isinstance(created_at, str):
            created_at = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
        else:
            created_at = datetime.utcnow()

        job_request = JobRequest(
            job_id=job_data["job_id"],
            action=job_data.get("action", "create"),
            resource_type=job_data["resource_type"],
            name=job_data["name"],
            environment=job_data.get("environment", "dev"),
            region=job_data.get("region", "us-east-1"),
            config=job_data.get("config", {}),
            tags=job_data.get("tags", {}),
            created_at=created_at,
        )

        # Create worker instance and process the job
        worker = TerraformWorker()
        return worker.process_infrastructure_job(job_request.json())

    except Exception as e:
        logger.error(f"Failed to process job: {str(e)}")
        raise Exception(f"Job processing failed: {str(e)}")


def start_worker():
    """Start the RQ worker"""
    redis_manager = RedisConnectionManager()
    redis_conn = redis_manager.get_rq_connection()  # Use RQ-specific connection

    queues = [
        Queue("default", connection=redis_conn),
        Queue("high", connection=redis_conn),
        Queue("low", connection=redis_conn),
    ]

    worker = Worker(queues, connection=redis_conn)
    logger.info("Starting RQ worker with connection pooling...")
    worker.work()


if __name__ == "__main__":
    start_worker()
