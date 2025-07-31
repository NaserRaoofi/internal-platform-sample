"""
Logging Configuration - Production-grade logging setup
====================================================

Centralized logging configuration for the entire platform.
"""

import logging
import logging.handlers
import sys
from pathlib import Path
from typing import Optional


def setup_logging(
    level: str = "INFO",
    log_file: Optional[str] = None,
    service_name: str = "internal-platform",
) -> logging.Logger:
    """
    Setup centralized logging configuration

    Args:
        level: Logging level (DEBUG, INFO, WARNING, ERROR)
        log_file: Optional log file path
        service_name: Service name for log identification

    Returns:
        Configured logger instance
    """

    # Create logs directory if it doesn't exist
    if log_file:
        log_dir = Path(log_file).parent
        log_dir.mkdir(parents=True, exist_ok=True)

    # Configure logging format
    log_format = (
        "%(asctime)s - %(name)s - %(levelname)s - "
        f"[{service_name}] - %(message)s"
    )

    # Configure date format
    date_format = "%Y-%m-%d %H:%M:%S"

    # Set logging level
    log_level = getattr(logging, level.upper(), logging.INFO)

    # Configure root logger
    logging.basicConfig(
        level=log_level, format=log_format, datefmt=date_format, handlers=[]
    )

    # Get root logger
    logger = logging.getLogger()
    logger.handlers.clear()  # Clear existing handlers

    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(log_level)
    console_formatter = logging.Formatter(log_format, date_format)
    console_handler.setFormatter(console_formatter)
    logger.addHandler(console_handler)

    # File handler (if specified)
    if log_file:
        file_handler = logging.handlers.RotatingFileHandler(
            log_file, maxBytes=10 * 1024 * 1024, backupCount=5  # 10MB
        )
        file_handler.setLevel(log_level)
        file_formatter = logging.Formatter(log_format, date_format)
        file_handler.setFormatter(file_formatter)
        logger.addHandler(file_handler)

    # Add job-specific logger
    job_logger = logging.getLogger("jobs")
    job_logger.setLevel(log_level)

    return logger


def get_job_logger(job_id: str) -> logging.Logger:
    """Get a job-specific logger"""
    logger = logging.getLogger(f"jobs.{job_id}")
    return logger


def log_job_start(job_id: str, action: str, resource_type: str):
    """Log job start event"""
    logger = get_job_logger(job_id)
    message = f"Starting {action} job for {resource_type} - Job ID: {job_id}"
    logger.info(message)


def log_job_completion(job_id: str, success: bool, duration: float):
    """Log job completion event"""
    logger = get_job_logger(job_id)
    status = "SUCCESS" if success else "FAILED"
    message = (
        f"Job {job_id} completed with status: {status} - "
        f"Duration: {duration:.2f}s"
    )
    logger.info(message)


def log_terraform_output(job_id: str, output: str, level: str = "INFO"):
    """Log Terraform command output"""
    logger = get_job_logger(job_id)
    log_level = getattr(logging, level.upper(), logging.INFO)
    logger.log(log_level, f"Terraform Output: {output}")


# Production-grade error logging
class ErrorContext:
    """Context manager for error logging"""

    def __init__(self, job_id: str, operation: str):
        self.job_id = job_id
        self.operation = operation
        self.logger = get_job_logger(job_id)

    def __enter__(self):
        self.logger.info(f"Starting operation: {self.operation}")
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if exc_type:
            error_msg = f"Operation '{self.operation}' failed: {exc_val}"
            self.logger.error(error_msg, exc_info=True)
            return False
        else:
            success_msg = (
                f"Operation '{self.operation}' completed successfully"
            )
            self.logger.info(success_msg)
            return True
