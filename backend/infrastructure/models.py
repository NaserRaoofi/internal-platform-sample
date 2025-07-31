"""
SQLAlchemy Database Models - Persistent Data Storage
==================================================

SQLite models for long-term data storage while Redis handles
caching and job queues.
"""

from datetime import datetime

from sqlalchemy import (
    JSON,
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship

Base = declarative_base()


class User(Base):
    """User management - persistent storage"""

    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, nullable=False, index=True)
    email = Column(String(100), unique=True, index=True)
    role = Column(String(20), nullable=False)  # 'admin' or 'developer'
    password_hash = Column(String(255))  # For future authentication
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )
    is_active = Column(Boolean, default=True)
    last_login = Column(DateTime)

    # Relationships
    jobs = relationship("InfrastructureJob", back_populates="user")
    audit_logs = relationship("AuditLog", back_populates="user")
    resources = relationship("InfrastructureResource", back_populates="user")


class InfrastructureResource(Base):
    """Infrastructure resources - track actual created resources"""

    __tablename__ = "infrastructure_resources"

    id = Column(Integer, primary_key=True, index=True)
    # AWS resource ID
    resource_id = Column(String(255), unique=True, index=True)
    job_id = Column(
        String(36), ForeignKey("infrastructure_jobs.job_id"), index=True
    )
    user_id = Column(
        Integer, ForeignKey("users.id"), nullable=False, index=True
    )

    # Resource Details
    # s3, ec2, etc
    resource_type = Column(String(50), nullable=False, index=True)
    resource_name = Column(String(100), nullable=False)  # user-provided name
    aws_arn = Column(String(500))  # AWS ARN for resource
    region = Column(String(30), default="us-east-1")
    environment = Column(String(20), default="dev", index=True)

    # Resource State
    # active, destroyed
    status = Column(String(20), default="active", index=True)
    terraform_state = Column(JSON)  # Terraform state info
    resource_config = Column(JSON)  # Configuration used to create
    resource_outputs = Column(JSON)  # Terraform outputs

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    destroyed_at = Column(DateTime)

    # Relationships
    user = relationship("User", back_populates="resources")
    job = relationship("InfrastructureJob")

    __table_args__ = (
        UniqueConstraint('resource_name', 'environment', 'user_id',
                         name='_resource_name_env_user_uc'),
    )


class InfrastructureJob(Base):
    """Job history - persistent storage for completed jobs"""

    __tablename__ = "infrastructure_jobs"

    id = Column(Integer, primary_key=True, index=True)
    job_id = Column(String(36), unique=True, index=True)  # UUID as string
    user_id = Column(
        Integer, ForeignKey("users.id"), nullable=False, index=True
    )

    # Job Details
    resource_type = Column(String(50), nullable=False, index=True)
    resource_name = Column(String(100), nullable=False)
    environment = Column(String(20), default="dev", index=True)
    region = Column(String(30), default="us-east-1")

    # Job Status & Results
    status = Column(String(20), nullable=False, index=True)
    config = Column(JSON)  # JSON for SQLite compatibility
    terraform_output = Column(JSON)
    error_message = Column(Text)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    started_at = Column(DateTime)
    completed_at = Column(DateTime)

    # Relationships
    user = relationship("User", back_populates="jobs")
    logs = relationship(
        "JobLog", back_populates="job", cascade="all, delete-orphan"
    )


class JobLog(Base):
    """Job logs - persistent storage for debugging and audit"""

    __tablename__ = "job_logs"

    id = Column(Integer, primary_key=True, index=True)
    job_id = Column(
        String(36),
        ForeignKey("infrastructure_jobs.job_id"),
        nullable=False,
        index=True,
    )

    # Log Details
    message = Column(Text, nullable=False)
    level = Column(String(10), default="INFO", index=True)  # DEBUG, INFO, etc
    step = Column(String(50))  # terraform init, plan, apply, etc.

    # Timestamp
    created_at = Column(DateTime, default=datetime.utcnow, index=True)

    # Relationships
    job = relationship("InfrastructureJob", back_populates="logs")


class AuditLog(Base):
    """Audit trail - compliance and security tracking"""

    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer, ForeignKey("users.id"), nullable=False, index=True
    )

    # Action Details
    action = Column(String(100), nullable=False, index=True)  # actions
    resource_type = Column(String(50), index=True)
    resource_id = Column(String(100), index=True)

    # Request Details
    details = Column(JSON)  # Store request payload, IP, etc.
    ip_address = Column(String(45))  # IPv4/IPv6
    user_agent = Column(String(500))

    # Result
    success = Column(Boolean, default=True, index=True)
    error_message = Column(Text)

    # Timestamp
    created_at = Column(DateTime, default=datetime.utcnow, index=True)

    # Relationships
    user = relationship("User", back_populates="audit_logs")


class SystemMetrics(Base):
    """System performance metrics - time-series data"""

    __tablename__ = "system_metrics"

    id = Column(Integer, primary_key=True, index=True)

    # Metrics
    active_jobs = Column(Integer, default=0)
    queued_jobs = Column(Integer, default=0)
    completed_jobs_today = Column(Integer, default=0)
    failed_jobs_today = Column(Integer, default=0)

    # System Resources
    redis_memory_usage = Column(Integer)  # bytes
    redis_connected_clients = Column(Integer)
    queue_size = Column(Integer)

    # Performance
    avg_job_duration = Column(Integer)  # seconds

    # Timestamp
    recorded_at = Column(DateTime, default=datetime.utcnow, index=True)
