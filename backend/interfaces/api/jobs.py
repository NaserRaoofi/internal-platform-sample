"""
Job Management API Routes
========================
"""

import logging
import json
import asyncio
import os
import shutil
from datetime import datetime
from fastapi import APIRouter, HTTPException, BackgroundTasks, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from domain.models import JobResult, JobStatus, JobLog, JobProgress
from infrastructure.database import get_db
from infrastructure.models import InfrastructureJob, JobLog as DBJobLog

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api", tags=["jobs"])

# Configuration
TERRAFORM_WORKSPACE_DIR = os.getenv(
    "TERRAFORM_WORKSPACE_DIR",
    "/tmp/terraform-workspaces"
)

# Redis for temporary job status (running jobs)
job_storage = {}  # Keep for running jobs, persist completed ones to DB


class CreateJobRequest(BaseModel):
    job_id: str
    action: str
    resource_type: str
    name: str
    environment: str = "dev"
    region: str = "us-east-1"
    config: dict = {}


@router.post("/jobs/create")
async def create_deployment_job(
    job_request: CreateJobRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    """Create a new deployment job"""
    try:
        # Create database entry for the job
        db_job = InfrastructureJob(
            job_id=job_request.job_id,
            user_id=1,  # TODO: Get from authentication
            resource_type=job_request.resource_type,
            resource_name=job_request.name,
            environment=job_request.environment,
            region=job_request.region,
            status="QUEUED",
            config=job_request.config,
            created_at=datetime.utcnow()
        )
        
        db.add(db_job)
        db.commit()
        db.refresh(db_job)
        
        # Add initial log entry
        msg = (f"Job {job_request.job_id} queued for "
               f"{job_request.resource_type} deployment")
        initial_log = DBJobLog(
            job_id=job_request.job_id,
            level="INFO",
            message=msg,
            step="initialization",
            timestamp=datetime.utcnow()
        )
        db.add(initial_log)
        db.commit()
        
        # Create job result entry for temporary storage during execution
        job_result = JobResult(
            job_id=job_request.job_id,
            status=JobStatus.QUEUED,
            logs=[
                JobLog(
                    timestamp=datetime.utcnow(),
                    level="INFO",
                    message=msg,
                    step="initialization"
                )
            ],
            progress=JobProgress(
                current_step="Queued",
                total_steps=5,
                completed_steps=0,
                percentage=0
            )
        )
        
        # Store in memory for active job processing
        job_storage[job_request.job_id] = job_result
        
        # Start background deployment process
        background_tasks.add_task(
            process_deployment_job,
            job_request.job_id,
            job_request
        )
        
        return {
            "job_id": job_request.job_id,
            "status": "queued",
            "message": "Deployment job created successfully"
        }
        
    except Exception as e:
        logger.error(f"Failed to create deployment job: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/jobs/{job_id}")
async def get_job_status(job_id: str, db: Session = Depends(get_db)):
    """Get job status and details"""
    try:
        # First check database for persistent job data
        db_job = db.query(InfrastructureJob).filter(
            InfrastructureJob.job_id == job_id
        ).first()
        
        if not db_job:
            # Fallback to in-memory storage for backward compatibility
            if job_id not in job_storage:
                raise HTTPException(status_code=404, detail="Job not found")
            job_result = job_storage[job_id]
            
            return {
                "job_id": job_id,
                "status": job_result.status,
                "started_at": (job_result.started_at.isoformat()
                               if job_result.started_at is not None
                               else None),
                "completed_at": (job_result.completed_at.isoformat()
                                 if job_result.completed_at is not None
                                 else None),
                "error_message": job_result.error_message,
                "terraform_output": job_result.terraform_output,
                "progress": {
                    "current_step": job_result.progress.current_step,
                    "total_steps": job_result.progress.total_steps,
                    "completed_steps": job_result.progress.completed_steps,
                    "percentage": job_result.progress.percentage,
                } if job_result.progress else None,
                "logs": [
                    {
                        "timestamp": log.timestamp.isoformat(),
                        "level": log.level,
                        "message": log.message,
                        "step": log.step
                    }
                    for log in job_result.logs
                ]
            }
        
        # Get logs from database
        db_logs = db.query(DBJobLog).filter(
            DBJobLog.job_id == job_id
        ).order_by(DBJobLog.timestamp.asc()).all()
        
        # Check if job is still running in memory for progress
        progress_data = None
        if job_id in job_storage:
            job_result = job_storage[job_id]
            if job_result.progress:
                progress_data = {
                    "current_step": job_result.progress.current_step,
                    "total_steps": job_result.progress.total_steps,
                    "completed_steps": job_result.progress.completed_steps,
                    "percentage": job_result.progress.percentage,
                }
        
        return {
            "job_id": job_id,
            "status": db_job.status,
            "started_at": (db_job.started_at.isoformat()
                           if db_job.started_at is not None else None),
            "completed_at": (db_job.completed_at.isoformat()
                             if db_job.completed_at is not None else None),
            "error_message": db_job.error_message,
            "terraform_output": db_job.terraform_output,
            "progress": progress_data,
            "logs": [
                {
                    "timestamp": log.timestamp.isoformat(),
                    "level": log.level,
                    "message": log.message,
                    "step": log.step
                }
                for log in db_logs
            ]
        }
        
    except Exception as e:
        logger.error(f"Failed to get job status: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


async def process_deployment_job(job_id: str, job_request: CreateJobRequest):
    """Background task to process deployment job"""
    try:
        # Get database session
        db = next(get_db())
        
        try:
            # Update job status to RUNNING in database
            db_job = db.query(InfrastructureJob).filter(
                InfrastructureJob.job_id == job_id
            ).first()
            
            if db_job:
                db_job.status = "RUNNING"
                db_job.started_at = datetime.utcnow()
                db.commit()
            
            # Add log entry for start
            start_log = DBJobLog(
                job_id=job_id,
                level="INFO",
                message=f"Starting deployment for job {job_id}",
                step="deployment_start",
                timestamp=datetime.utcnow()
            )
            db.add(start_log)
            db.commit()
            
            # Update in-memory job for UI polling (temporary)
            if job_id in job_storage:
                job_storage[job_id].status = JobStatus.RUNNING
                job_storage[job_id].started_at = datetime.utcnow()
                job_storage[job_id].logs.append(
                    JobLog(
                        timestamp=datetime.utcnow(),
                        level="INFO",
                        message=f"Starting deployment for job {job_id}",
                        step="deployment_start"
                    )
                )
        
            # Always use real Terraform deployment for production
            await process_real_terraform_deployment(job_id, job_request)
                
        finally:
            db.close()
            
    except Exception as e:
        logger.error(f"Deployment job {job_id} failed: {str(e)}")
        
        # Update database with error
        try:
            db = next(get_db())
            db_job = db.query(InfrastructureJob).filter(
                InfrastructureJob.job_id == job_id
            ).first()
            
            if db_job:
                db_job.status = "FAILED"
                db_job.completed_at = datetime.utcnow()
                db_job.error_message = str(e)
                db.commit()
                
            # Add error log
            error_log = DBJobLog(
                job_id=job_id,
                level="ERROR",
                message=f"Deployment failed: {str(e)}",
                step="error",
                timestamp=datetime.utcnow()
            )
            db.add(error_log)
            db.commit()
            db.close()
        except Exception as db_error:
            logger.error(f"Failed to update database with error: {db_error}")
        
        # Update in-memory job (temporary)
        if job_id in job_storage:
            job_result = job_storage[job_id]
            job_result.status = JobStatus.FAILED
            job_result.completed_at = datetime.utcnow()
            job_result.error_message = str(e)
            job_result.logs.append(JobLog(
                level="ERROR",
                message=f"Deployment failed: {str(e)}",
                step="error"
            ))


async def process_real_terraform_deployment(
    job_id: str,
    job_request: CreateJobRequest
):
    """Process deployment with real Terraform execution"""
    job_result = job_storage[job_id]
    
    # Update job to running
    job_result.status = JobStatus.RUNNING
    job_result.started_at = datetime.utcnow()
    
    # Create workspace directory for this job
    workspace_dir = f"{TERRAFORM_WORKSPACE_DIR}/{job_id}"
    os.makedirs(workspace_dir, exist_ok=True)
    
    # Step 1: Validation
    await update_job_progress(
        job_id, "Validation", 1, 5,
        "Validating configuration and environment..."
    )
    
    # Validate AWS credentials and environment
    validation_result = await run_terraform_command(
        job_id, workspace_dir,
        "aws sts get-caller-identity",
        "validation"
    )
    
    if not validation_result["success"]:
        raise Exception("AWS credentials validation failed")
    
    job_result.logs.append(JobLog(
        message="Environment validation completed successfully",
        step="validation"
    ))
    
    # Step 2: Setup Terraform workspace
    await update_job_progress(
        job_id, "Terraform Setup", 2, 5,
        "Setting up Terraform workspace..."
    )
    
    # Copy appropriate template based on resource type
    template_source = get_template_path(job_request.resource_type)
    await setup_terraform_workspace(
        job_id, workspace_dir, template_source, job_request
    )
    
    job_result.logs.append(JobLog(
        message="Terraform workspace setup completed",
        step="terraform_setup"
    ))
    
    # Step 3: Terraform Init
    await update_job_progress(
        job_id, "Terraform Init", 3, 5,
        "Initializing Terraform..."
    )
    
    init_result = await run_terraform_command(
        job_id, workspace_dir,
        "terraform init",
        "terraform_init"
    )
    
    if not init_result["success"]:
        raise Exception(f"Terraform init failed: {init_result['error']}")
    
    job_result.logs.append(JobLog(
        message="Terraform initialization completed successfully",
        step="terraform_init"
    ))
    
    # Step 4: Terraform Plan
    await update_job_progress(
        job_id, "Terraform Plan", 4, 5,
        "Generating Terraform plan..."
    )
    
    plan_result = await run_terraform_command(
        job_id, workspace_dir,
        "terraform plan -out=tfplan",
        "terraform_plan"
    )
    
    if not plan_result["success"]:
        raise Exception(f"Terraform plan failed: {plan_result['error']}")
    
    job_result.logs.append(JobLog(
        message="Terraform plan generated successfully",
        step="terraform_plan"
    ))
    
    # Step 5: Terraform Apply
    await update_job_progress(
        job_id, "Terraform Apply", 5, 5,
        "Applying Terraform configuration..."
    )
    
    apply_result = await run_terraform_command(
        job_id, workspace_dir,
        "terraform apply -auto-approve tfplan",
        "terraform_apply"
    )
    
    if not apply_result["success"]:
        raise Exception(f"Terraform apply failed: {apply_result['error']}")
    
    # Get terraform outputs
    output_result = await run_terraform_command(
        job_id, workspace_dir,
        "terraform output -json",
        "terraform_output"
    )
    
    if output_result["success"]:
        job_result.terraform_output = json.loads(output_result["stdout"])
    
    job_result.logs.append(JobLog(
        message=(f"Successfully deployed {job_request.resource_type}: "
                 f"{job_request.name}"),
        step="terraform_apply"
    ))
    
    # Mark as completed
    job_result.status = JobStatus.COMPLETED
    job_result.completed_at = datetime.utcnow()
    job_result.progress.percentage = 100
    
    # Update database with completion
    try:
        db = next(get_db())
        db_job = db.query(InfrastructureJob).filter(
            InfrastructureJob.job_id == job_id
        ).first()
        
        if db_job:
            db_job.status = "COMPLETED"
            db_job.completed_at = datetime.utcnow()
            db_job.terraform_output = job_result.terraform_output
            db.commit()
            
        # Add completion log
        completion_log = DBJobLog(
            job_id=job_id,
            level="INFO",
            message="Deployment completed successfully",
            step="completion",
            timestamp=datetime.utcnow()
        )
        db.add(completion_log)
        db.commit()
        db.close()
    except Exception as db_error:
        logger.error(f"Failed to update database on completion: {db_error}")


async def run_terraform_command(
    job_id: str,
    workspace_dir: str,
    command: str,
    step: str
):
    """Execute a shell command and return the result"""
    try:
        # Set environment variables for Terraform
        env = os.environ.copy()
        env.update({
            "TF_IN_AUTOMATION": "true",
            "TF_LOG": "INFO",
            "AWS_REGION": "us-east-1"  # Default region
        })
        
        # Run command
        process = await asyncio.create_subprocess_shell(
            command,
            cwd=workspace_dir,
            env=env,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await process.communicate()
        
        # Log the command output
        job_result = job_storage[job_id]
        
        if stdout:
            stdout_str = stdout.decode()
            job_result.logs.append(JobLog(
                message=f"Command output: {stdout_str[:500]}...",
                step=step
            ))
        
        if stderr:
            stderr_str = stderr.decode()
            job_result.logs.append(JobLog(
                level="WARN" if process.returncode == 0 else "ERROR",
                message=f"Command stderr: {stderr_str[:500]}...",
                step=step
            ))
        
        return {
            "success": process.returncode == 0,
            "stdout": stdout.decode() if stdout else "",
            "stderr": stderr.decode() if stderr else "",
            "error": stderr.decode() if process.returncode != 0 else None
        }
        
    except Exception as e:
        return {
            "success": False,
            "stdout": "",
            "stderr": "",
            "error": str(e)
        }


async def setup_terraform_workspace(
    job_id: str,
    workspace_dir: str,
    template_source: str,
    job_request: CreateJobRequest
):
    """Setup Terraform workspace with appropriate template"""
    try:
        # Copy template files
        if os.path.exists(template_source):
            for item in os.listdir(template_source):
                source_path = os.path.join(template_source, item)
                dest_path = os.path.join(workspace_dir, item)
                
                if os.path.isfile(source_path):
                    shutil.copy2(source_path, dest_path)
                elif os.path.isdir(source_path):
                    shutil.copytree(source_path, dest_path)
        else:
            # Create a basic Terraform configuration for the resource
            await create_basic_terraform_config(workspace_dir, job_request)
        
        # Create terraform.tfvars with job-specific values
        tfvars_content = f"""
# Generated variables for job {job_id}
bucket_name = "{job_request.name}"
environment = "{job_request.environment}"
region = "{job_request.region}"

tags = {{
  JobId = "{job_id}"
  ManagedBy = "InternalPlatform"
  CreatedAt = "{datetime.utcnow().isoformat()}"
}}
"""
        
        with open(os.path.join(workspace_dir, "terraform.tfvars"), "w") as f:
            f.write(tfvars_content)
            
    except Exception as e:
        raise Exception(f"Failed to setup Terraform workspace: {str(e)}")


async def create_basic_terraform_config(
    workspace_dir: str,
    job_request: CreateJobRequest
):
    """Create a basic Terraform configuration if template doesn't exist"""
    
    if job_request.resource_type.lower() == "s3":
        main_tf_content = """
terraform {{
  required_providers {{
    aws = {{
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }}
  }}
}}

provider "aws" {{
  region = var.region
}}

variable "bucket_name" {{
  description = "Name of the S3 bucket"
  type        = string
}}

variable "environment" {{
  description = "Environment name"
  type        = string
  default     = "dev"
}}

variable "region" {{
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}}

variable "tags" {{
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {{}}
}}

resource "random_id" "bucket_suffix" {{
  byte_length = 4
}}

resource "aws_s3_bucket" "main" {{
  bucket = "${{var.bucket_name}}-${{random_id.bucket_suffix.hex}}"
  
  tags = merge(var.tags, {{
    Name = "${{var.bucket_name}}-${{random_id.bucket_suffix.hex}}"
    Type = "s3-bucket"
  }})
}}

resource "aws_s3_bucket_versioning" "main" {{
  bucket = aws_s3_bucket.main.id
  versioning_configuration {{
    status = "Enabled"
  }}
}}

output "bucket_name" {{
  description = "Name of the created S3 bucket"
  value       = aws_s3_bucket.main.bucket
}}

output "bucket_arn" {{
  description = "ARN of the created S3 bucket"
  value       = aws_s3_bucket.main.arn
}}
"""
        
        with open(os.path.join(workspace_dir, "main.tf"), "w") as f:
            f.write(main_tf_content)


def get_template_path(resource_type: str) -> str:
    """Get the template path for a given resource type"""
    base_path = "/home/sirwan/IDP/internal-platform-sample/terraform"
    
    # Map resource types to existing templates/modules
    template_map = {
        "s3": f"{base_path}/modules/aws-s3",
        "ec2": f"{base_path}/modules/aws-ec2",
        "rds": f"{base_path}/modules/aws-rds",
        "cloudfront": f"{base_path}/modules/aws-cloudfront",
        "sirwan-test": f"{base_path}/templates/sirwan-test"
    }
    
    return template_map.get(resource_type.lower(), "")


async def update_job_progress(
    job_id: str,
    step_name: str,
    completed: int,
    total: int,
    message: str
):
    """Update job progress"""
    job_result = job_storage[job_id]
    job_result.progress = JobProgress(
        current_step=step_name,
        total_steps=total,
        completed_steps=completed,
        percentage=int((completed / total) * 100)
    )
    job_result.logs.append(JobLog(
        message=message,
        step=step_name.lower().replace(" ", "_")
    ))
