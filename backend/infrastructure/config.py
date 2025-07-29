"""
Configuration Management - Environment-based settings
====================================================

Production-grade configuration with environment variables,
secrets management, and validation.
"""

import os
from typing import Optional
from pydantic import BaseSettings, Field

class Settings(BaseSettings):
    """Application settings with environment variable support"""
    
    # Application
    app_name: str = Field(default="Cloud Automation Platform", env="APP_NAME")
    debug: bool = Field(default=False, env="DEBUG")
    environment: str = Field(default="development", env="ENVIRONMENT")
    
    # Redis Configuration
    redis_host: str = Field(default="localhost", env="REDIS_HOST")
    redis_port: int = Field(default=6379, env="REDIS_PORT")
    redis_db: int = Field(default=0, env="REDIS_DB")
    redis_password: Optional[str] = Field(default=None, env="REDIS_PASSWORD")
    
    # Database Configuration
    database_url: str = Field(default="sqlite:///./jobs.db", env="DATABASE_URL")
    
    # AWS Configuration
    aws_access_key_id: Optional[str] = Field(default=None, env="AWS_ACCESS_KEY_ID")
    aws_secret_access_key: Optional[str] = Field(default=None, env="AWS_SECRET_ACCESS_KEY")
    aws_default_region: str = Field(default="us-east-1", env="AWS_DEFAULT_REGION")
    
    # Terraform Configuration
    terraform_binary_path: str = Field(default="terraform", env="TERRAFORM_BINARY_PATH")
    terraform_templates_dir: str = Field(default="terraform/templates", env="TERRAFORM_TEMPLATES_DIR")
    terraform_instances_dir: str = Field(default="terraform/instances", env="TERRAFORM_INSTANCES_DIR")
    
    # Job Configuration
    job_timeout_minutes: int = Field(default=30, env="JOB_TIMEOUT_MINUTES")
    max_concurrent_jobs: int = Field(default=5, env="MAX_CONCURRENT_JOBS")
    
    # Security
    secret_key: str = Field(default="dev-secret-key-change-in-production", env="SECRET_KEY")
    cors_origins: list = Field(default=["http://localhost:3000"], env="CORS_ORIGINS")
    
    # Logging
    log_level: str = Field(default="INFO", env="LOG_LEVEL")
    log_file: Optional[str] = Field(default=None, env="LOG_FILE")
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

# Global settings instance
_settings: Optional[Settings] = None

def get_settings() -> Settings:
    """Get application settings (singleton pattern)"""
    global _settings
    if _settings is None:
        _settings = Settings()
    return _settings

def reload_settings():
    """Reload settings (useful for testing)"""
    global _settings
    _settings = None
    return get_settings()
