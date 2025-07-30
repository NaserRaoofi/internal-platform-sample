"""
Database Manager - SQLite + Redis Architecture
=============================================

SQLite: Persistent data storage (Users, Jobs, Audit logs, etc.)
Redis: Caching and job queues only (temporary data)
"""

import json
import logging
from typing import Any, Dict, Optional

from redis import Redis
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, Session

from infrastructure.config import get_settings
from infrastructure.models import Base

logger = logging.getLogger(__name__)
settings = get_settings()


class SQLiteManager:
    """SQLite database operations for persistent data"""

    def __init__(self):
        # SQLite connection for persistent data
        self.engine = create_engine(
            settings.database_url,
            echo=settings.debug,
            pool_pre_ping=True,
            connect_args={"check_same_thread": False}  # SQLite specific
        )
        
        self.SessionLocal = sessionmaker(
            autocommit=False,
            autoflush=False,
            bind=self.engine
        )

    def health_check(self) -> bool:
        """Check SQLite connectivity"""
        try:
            with self.SessionLocal() as session:
                session.execute(text("SELECT 1")).fetchone()
                return True
        except Exception as e:
            logger.error(f"SQLite health check failed: {str(e)}")
            return False

    def create_tables(self):
        """Create all tables"""
        try:
            Base.metadata.create_all(bind=self.engine)
            logger.info("SQLite tables created successfully")
        except Exception as e:
            logger.error(f"Failed to create tables: {str(e)}")
            raise

    def get_session(self) -> Session:
        """Get database session"""
        return self.SessionLocal()


class RedisCacheManager:
    """Redis operations for caching and temporary data only"""

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
        """Check Redis connectivity"""
        try:
            result = self.redis.ping()
            return bool(result)
        except Exception as e:
            logger.error(f"Redis health check failed: {str(e)}")
            return False

    # Job Progress Caching (temporary data)
    def cache_job_progress(self, job_id: str, progress: Dict[str, Any],
                           ttl: int = 3600) -> bool:
        """Cache temporary job progress data"""
        try:
            key = f"job_progress:{job_id}"
            value = json.dumps(progress)
            self.redis.setex(key, ttl, value)
            return True
        except Exception as e:
            logger.error(f"Failed to cache job progress {job_id}: {str(e)}")
            return False

    def get_job_progress(self, job_id: str) -> Optional[Dict[str, Any]]:
        """Get cached job progress"""
        try:
            key = f"job_progress:{job_id}"
            data = self.redis.get(key)
            if data:
                return json.loads(data)
            return None
        except Exception as e:
            logger.error(f"Failed to get job progress {job_id}: {str(e)}")
            return None

    # Session Management
    def store_session(self, session_id: str, session_data: Dict[str, Any],
                      ttl: int = 3600) -> bool:
        """Store user session data"""
        try:
            key = f"session:{session_id}"
            value = json.dumps(session_data)
            self.redis.setex(key, ttl, value)
            return True
        except Exception as e:
            logger.error(f"Failed to store session: {str(e)}")
            return False

    def get_session(self, session_id: str) -> Optional[Dict[str, Any]]:
        """Get session data"""
        try:
            key = f"session:{session_id}"
            data = self.redis.get(key)
            if data:
                return json.loads(data)
            return None
        except Exception as e:
            logger.error(f"Failed to get session: {str(e)}")
            return None

    # General Caching
    def cache_set(self, key: str, value: Any, ttl: int = 3600) -> bool:
        """Generic cache set operation"""
        try:
            if isinstance(value, (dict, list)):
                value = json.dumps(value)
            elif not isinstance(value, str):
                value = str(value)

            self.redis.setex(key, ttl, value)
            return True
        except Exception as e:
            logger.error(f"Failed to cache key {key}: {str(e)}")
            return False

    def cache_get(self, key: str) -> Optional[str]:
        """Generic cache get operation"""
        try:
            return self.redis.get(key)
        except Exception as e:
            logger.error(f"Failed to get cache key {key}: {str(e)}")
            return None


class DatabaseManager:
    """Combined database manager for SQLite + Redis"""

    def __init__(self):
        self.sqlite = SQLiteManager()
        self.redis = RedisCacheManager()

    def health_check(self) -> Dict[str, bool]:
        """Check both SQLite and Redis health"""
        return {
            "sqlite": self.sqlite.health_check(),
            "redis": self.redis.health_check()
        }

    def initialize_database(self):
        """Initialize the database"""
        self.sqlite.create_tables()
        logger.info("Database initialization completed")


# Global instances
sqlite_manager = SQLiteManager()
redis_cache = RedisCacheManager()
db_manager = DatabaseManager()


# FastAPI dependency
def get_db() -> Session:
    """Get database session for FastAPI dependency injection"""
    db = sqlite_manager.get_session()
    try:
        yield db
    finally:
        db.close()
