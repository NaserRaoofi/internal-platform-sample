"""
Configuration Management - Environment-based settings
====================================================

Production-grade configuration with environment variables,
secrets management, and validation.
"""

from typing import Optional

from pydantic_settings import BaseSettings  # type: ignore


class Settings(BaseSettings):
    """Application settings with environment variable support"""

    # Application
    app_name: str = "Cloud Automation Platform"
    debug: bool = False
    environment: str = "development"

    # Redis Configuration
    redis_host: str = "localhost"
    redis_port: int = 6379
    redis_db: int = 0
    redis_password: Optional[str] = None

    # Database Configuration
    database_url: str = "sqlite:///./internal_platform.db"
    database_url_async: str = "sqlite+aiosqlite:///./internal_platform.db"

    # AWS Configuration
    aws_access_key_id: Optional[str] = None
    aws_secret_access_key: Optional[str] = None
    aws_default_region: str = "us-east-1"

    # Terraform Configuration
    terraform_binary_path: str = "terraform"
    terraform_templates_dir: str = "terraform/templates"
    terraform_instances_dir: str = "terraform/instances"

    # Job Configuration
    job_timeout_minutes: int = 30
    max_concurrent_jobs: int = 5
    job_result_ttl: int = 3600  # 1 hour in seconds

    # Terraform Configuration
    terraform_dir: str = "../terraform"

    # Security
    secret_key: str = "dev-secret-key-change-in-production"
    cors_origins: list = ["http://localhost:3000"]

    # Logging
    log_level: str = "INFO"
    log_file: Optional[str] = None

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
