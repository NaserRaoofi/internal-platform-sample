"""
Database Manager - SQLite + Redis Architecture with Async Support
================================================================

SQLite: Persistent data storage with async operations
Redis: Caching and job queues with proper connection pooling
"""

import json
import logging
from typing import Any, Dict, Generator, AsyncGenerator, Optional

from redis import ConnectionPool, Redis
from sqlalchemy import create_engine, text
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    create_async_engine,
    async_sessionmaker
)
from sqlalchemy.orm import Session, sessionmaker

from infrastructure.config import get_settings
from infrastructure.models import Base

logger = logging.getLogger(__name__)
settings = get_settings()


class RedisConnectionManager:
    """Redis connection manager with pooling and retry logic"""
    
    _instance = None
    _connection_pool = None
    _rq_connection_pool = None  # Separate pool for RQ
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    def __init__(self):
        if self._connection_pool is None:
            # General purpose pool with decoded responses
            self._connection_pool = ConnectionPool(
                host=settings.redis_host,
                port=settings.redis_port,
                password=settings.redis_password,
                decode_responses=True,
                max_connections=settings.redis_max_connections,
                socket_connect_timeout=settings.redis_socket_connect_timeout,
                socket_timeout=settings.redis_socket_timeout,
                socket_keepalive=True,
                socket_keepalive_options={},
                health_check_interval=settings.redis_health_check_interval,
                retry_on_timeout=True,
                retry_on_error=[ConnectionError, TimeoutError],
            )
            
            # RQ-specific pool without decoded responses
            self._rq_connection_pool = ConnectionPool(
                host=settings.redis_host,
                port=settings.redis_port,
                password=settings.redis_password,
                decode_responses=False,  # RQ needs binary data
                max_connections=settings.redis_max_connections,
                socket_connect_timeout=settings.redis_socket_connect_timeout,
                socket_timeout=settings.redis_socket_timeout,
                socket_keepalive=True,
                socket_keepalive_options={},
                health_check_interval=settings.redis_health_check_interval,
                retry_on_timeout=True,
                retry_on_error=[ConnectionError, TimeoutError],
            )
            logger.info(
                f"Redis connection pools initialized with "
                f"{settings.redis_max_connections} max connections each"
            )
    
    def get_connection(self) -> Redis:
        """Get Redis connection from general pool (with decoded responses)"""
        return Redis(connection_pool=self._connection_pool)
    
    def get_rq_connection(self) -> Redis:
        """Get Redis connection for RQ (without decoded responses)"""
        return Redis(connection_pool=self._rq_connection_pool)
    
    def health_check(self) -> bool:
        """Check Redis connectivity using pooled connection"""
        try:
            redis_conn = self.get_connection()
            result = redis_conn.ping()
            redis_conn.close()  # Return to pool
            return bool(result)
        except Exception as e:
            logger.error(f"Redis health check failed: {str(e)}")
            return False


class SQLiteManager:
    """SQLite database operations for persistent data (sync operations)"""

    def __init__(self):
        # SQLite connection for persistent data
        self.engine = create_engine(
            settings.database_url,
            echo=settings.debug,
            pool_pre_ping=True,
            connect_args={"check_same_thread": False},  # SQLite specific
        )

        self.SessionLocal = sessionmaker(
            autocommit=False, autoflush=False, bind=self.engine
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


class AsyncSQLiteManager:
    """Async SQLite database operations for high-performance endpoints"""

    def __init__(self):
        # Async SQLite connection for high-performance operations
        self.async_engine = create_async_engine(
            settings.database_url_async,
            echo=settings.debug,
            pool_pre_ping=True,
        )

        self.AsyncSessionLocal = async_sessionmaker(
            bind=self.async_engine,
            class_=AsyncSession,
            autocommit=False,
            autoflush=False,
        )

    async def health_check(self) -> bool:
        """Check async SQLite connectivity"""
        try:
            async with self.AsyncSessionLocal() as session:
                result = await session.execute(text("SELECT 1"))
                result.fetchone()
                return True
        except Exception as e:
            logger.error(f"Async SQLite health check failed: {str(e)}")
            return False

    async def get_session(self) -> AsyncSession:
        """Get async database session"""
        return self.AsyncSessionLocal()

    async def close(self):
        """Close async engine"""
        await self.async_engine.dispose()


class RedisCacheManager:
    """Redis operations for caching and temporary data with pooling"""

    def __init__(self):
        self.redis_manager = RedisConnectionManager()

    def health_check(self) -> bool:
        """Check Redis connectivity"""
        return self.redis_manager.health_check()

    # Job Progress Caching (temporary data)
    def cache_job_progress(
        self, job_id: str, progress: Dict[str, Any], ttl: int = 3600
    ) -> bool:
        """Cache temporary job progress data"""
        redis_conn = None
        try:
            redis_conn = self.redis_manager.get_connection()
            key = f"job_progress:{job_id}"
            value = json.dumps(progress)
            redis_conn.setex(key, ttl, value)
            return True
        except Exception as e:
            logger.error(f"Failed to cache job progress {job_id}: {str(e)}")
            return False
        finally:
            if redis_conn:
                redis_conn.close()  # Return to pool

    def get_job_progress(self, job_id: str) -> Optional[Dict[str, Any]]:
        """Get cached job progress"""
        redis_conn = None
        try:
            redis_conn = self.redis_manager.get_connection()
            key = f"job_progress:{job_id}"
            data = redis_conn.get(key)
            if data and isinstance(data, str):
                return json.loads(data)
            return None
        except Exception as e:
            logger.error(f"Failed to get job progress {job_id}: {str(e)}")
            return None
        finally:
            if redis_conn:
                redis_conn.close()

    # Session Management
    def store_session(
        self, session_id: str, session_data: Dict[str, Any], ttl: int = 3600
    ) -> bool:
        """Store user session data"""
        redis_conn = None
        try:
            redis_conn = self.redis_manager.get_connection()
            key = f"session:{session_id}"
            value = json.dumps(session_data)
            redis_conn.setex(key, ttl, value)
            return True
        except Exception as e:
            logger.error(f"Failed to store session: {str(e)}")
            return False
        finally:
            if redis_conn:
                redis_conn.close()

    def get_session(self, session_id: str) -> Optional[Dict[str, Any]]:
        """Get session data"""
        redis_conn = None
        try:
            redis_conn = self.redis_manager.get_connection()
            key = f"session:{session_id}"
            data = redis_conn.get(key)
            if data and isinstance(data, str):
                return json.loads(data)
            return None
        except Exception as e:
            logger.error(f"Failed to get session: {str(e)}")
            return None
        finally:
            if redis_conn:
                redis_conn.close()

    # General Caching
    def cache_set(self, key: str, value: Any, ttl: int = 3600) -> bool:
        """Generic cache set operation"""
        redis_conn = None
        try:
            redis_conn = self.redis_manager.get_connection()
            if isinstance(value, (dict, list)):
                value = json.dumps(value)
            elif not isinstance(value, str):
                value = str(value)

            redis_conn.setex(key, ttl, value)
            return True
        except Exception as e:
            logger.error(f"Failed to cache key {key}: {str(e)}")
            return False
        finally:
            if redis_conn:
                redis_conn.close()

    def cache_get(self, key: str) -> Optional[str]:
        """Generic cache get operation"""
        redis_conn = None
        try:
            redis_conn = self.redis_manager.get_connection()
            result = redis_conn.get(key)
            return result if isinstance(result, str) else None
        except Exception as e:
            logger.error(f"Failed to get cache key {key}: {str(e)}")
            return None
        finally:
            if redis_conn:
                redis_conn.close()


class DatabaseManager:
    """Combined database manager for SQLite + Redis with async support"""

    def __init__(self):
        self.sqlite = SQLiteManager()
        self.async_sqlite = AsyncSQLiteManager()
        self.redis = RedisCacheManager()

    def health_check(self) -> Dict[str, bool]:
        """Check both SQLite and Redis health (sync)"""
        return {
            "sqlite": self.sqlite.health_check(),
            "redis": self.redis.health_check(),
        }

    async def async_health_check(self) -> Dict[str, bool]:
        """Check both SQLite and Redis health (async)"""
        return {
            "sqlite": await self.async_sqlite.health_check(),
            "redis": self.redis.health_check(),
        }

    def initialize_database(self):
        """Initialize the database"""
        self.sqlite.create_tables()
        logger.info("Database initialization completed")

    async def close(self):
        """Close async connections"""
        await self.async_sqlite.close()

    # Async Deployment Request Operations for FastAPI endpoints
    async def create_deployment_request_async(
        self, request_data: Dict[str, Any]
    ) -> str:
        """Create a new deployment request in the database (async)"""
        from infrastructure.models import DeploymentRequest

        async with self.async_sqlite.AsyncSessionLocal() as session:
            try:
                db_request = DeploymentRequest(**request_data)
                session.add(db_request)
                await session.commit()
                await session.refresh(db_request)
                return str(db_request.request_id)  # Convert to string
            except Exception as e:
                await session.rollback()
                logger.error(f"Failed to create deployment request: {str(e)}")
                raise

    async def get_deployment_request_async(self, request_id: str):
        """Get deployment request by ID (async)"""
        from infrastructure.models import DeploymentRequest
        from sqlalchemy import select

        async with self.async_sqlite.AsyncSessionLocal() as session:
            result = await session.execute(
                select(DeploymentRequest).filter(
                    DeploymentRequest.request_id == request_id
                )
            )
            return result.scalar_one_or_none()

    async def get_all_deployment_requests_async(self):
        """Get all deployment requests (async)"""
        from infrastructure.models import DeploymentRequest
        from sqlalchemy import select

        async with self.async_sqlite.AsyncSessionLocal() as session:
            result = await session.execute(select(DeploymentRequest))
            return result.scalars().all()

    async def update_deployment_request_async(
        self, request_id: str, updates: Dict[str, Any]
    ) -> bool:
        """Update deployment request status and data (async)"""
        from infrastructure.models import DeploymentRequest
        from sqlalchemy import select

        async with self.async_sqlite.AsyncSessionLocal() as session:
            try:
                result = await session.execute(
                    select(DeploymentRequest).filter(
                        DeploymentRequest.request_id == request_id
                    )
                )
                request = result.scalar_one_or_none()
                if not request:
                    return False

                for key, value in updates.items():
                    if hasattr(request, key):
                        setattr(request, key, value)

                await session.commit()
                return True
            except Exception as e:
                await session.rollback()
                logger.error(f"Failed to update deployment request: {str(e)}")
                return False

    async def delete_deployment_request_async(self, request_id: str) -> bool:
        """Delete deployment request from database (async)"""
        from infrastructure.models import DeploymentRequest
        from sqlalchemy import select

        async with self.async_sqlite.AsyncSessionLocal() as session:
            try:
                result = await session.execute(
                    select(DeploymentRequest).filter(
                        DeploymentRequest.request_id == request_id
                    )
                )
                request = result.scalar_one_or_none()
                if not request:
                    return False

                await session.delete(request)
                await session.commit()
                return True
            except Exception as e:
                await session.rollback()
                logger.error(f"Failed to delete deployment request: {str(e)}")
                return False

    # Sync methods for backward compatibility
    def create_deployment_request(self, request_data: Dict[str, Any]) -> str:
        """Create a new deployment request in the database (sync)"""
        from infrastructure.models import DeploymentRequest

        db = self.sqlite.get_session()
        try:
            db_request = DeploymentRequest(**request_data)
            db.add(db_request)
            db.commit()
            db.refresh(db_request)
            return str(db_request.request_id)  # Convert to string
        except Exception as e:
            db.rollback()
            logger.error(f"Failed to create deployment request: {str(e)}")
            raise
        finally:
            db.close()

    def get_deployment_request(self, request_id: str):
        """Get deployment request by ID (sync)"""
        from infrastructure.models import DeploymentRequest

        db = self.sqlite.get_session()
        try:
            return db.query(DeploymentRequest).filter(
                DeploymentRequest.request_id == request_id
            ).first()
        finally:
            db.close()

    def get_all_deployment_requests(self):
        """Get all deployment requests (sync)"""
        from infrastructure.models import DeploymentRequest

        db = self.sqlite.get_session()
        try:
            return db.query(DeploymentRequest).all()
        finally:
            db.close()

    def update_deployment_request(
        self, request_id: str, updates: Dict[str, Any]
    ) -> bool:
        """Update deployment request status and data (sync)"""
        from infrastructure.models import DeploymentRequest

        db = self.sqlite.get_session()
        try:
            request = db.query(DeploymentRequest).filter(
                DeploymentRequest.request_id == request_id
            ).first()
            if not request:
                return False

            for key, value in updates.items():
                if hasattr(request, key):
                    setattr(request, key, value)

            db.commit()
            return True
        except Exception as e:
            db.rollback()
            logger.error(f"Failed to update deployment request: {str(e)}")
            return False
        finally:
            db.close()


# Global instances
sqlite_manager = SQLiteManager()
async_sqlite_manager = AsyncSQLiteManager()
redis_cache = RedisCacheManager()
db_manager = DatabaseManager()


# FastAPI dependency for sync operations
def get_db() -> Generator[Session, None, None]:
    """Get database session for FastAPI dependency injection (sync)"""
    db = sqlite_manager.get_session()
    try:
        yield db
    finally:
        db.close()


# FastAPI dependency for async operations
async def get_async_db() -> AsyncGenerator[AsyncSession, None]:
    """Get async database session for FastAPI dependency injection"""
    async with async_sqlite_manager.AsyncSessionLocal() as session:
        yield session
