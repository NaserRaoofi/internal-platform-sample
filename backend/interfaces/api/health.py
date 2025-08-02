"""
Health Check API Routes
======================
"""

import logging
from datetime import datetime

from fastapi import APIRouter
from fastapi.responses import JSONResponse
from rq import Queue

from infrastructure.config import get_settings
from infrastructure.database import DatabaseManager, RedisConnectionManager

logger = logging.getLogger(__name__)
router = APIRouter(tags=["health"])


@router.get("/health")
async def health_check():
    """Health check endpoint with real service verification"""
    try:
        settings = get_settings()
        service_status = {}
        overall_status = "healthy"

        # 1. Check Database (SQLite + Redis) Connection
        try:
            db_manager = DatabaseManager()
            db_health = await db_manager.async_health_check()
            service_status["database"] = {
                "sqlite": "operational" if db_health["sqlite"] else "down",
                "redis": "operational" if db_health["redis"] else "down",
            }
            if not db_health["sqlite"] or not db_health["redis"]:
                overall_status = "degraded"
        except Exception as e:
            logger.error(f"Database health check failed: {e}")
            service_status["database"] = {
                "sqlite": "down",
                "redis": "down",
            }
            overall_status = "degraded"

        # 2. Check Redis Queue System using connection pool
        try:
            redis_manager = RedisConnectionManager()
            redis_conn = redis_manager.get_connection()
            queue = Queue("default", connection=redis_conn)

            # Test queue connectivity by checking queue length
            queue_length = len(queue)
            service_status["queue"] = "operational"
            service_status["queue_jobs"] = queue_length
            
            # Close connection (return to pool)
            redis_conn.close()

        except Exception as e:
            logger.error(f"Queue health check failed: {e}")
            service_status["queue"] = "down"
            overall_status = "degraded"

        # 4. Add system information
        service_status["environment"] = settings.environment
        service_status["app_name"] = settings.app_name
        service_status["connection_pooling"] = "enabled"
        service_status["async_database"] = "enabled"

        # Return appropriate response based on overall health
        if overall_status == "healthy":
            return {
                "status": overall_status,
                "timestamp": datetime.utcnow().isoformat(),
                "services": service_status,
            }
        else:
            return JSONResponse(
                status_code=503,
                content={
                    "status": overall_status,
                    "timestamp": datetime.utcnow().isoformat(),
                    "services": service_status,
                },
            )

    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy",
                "error": str(e),
                "timestamp": datetime.utcnow().isoformat(),
                "services": {
                    "database": "unknown",
                    "redis": "unknown",
                    "queue": "unknown",
                },
            },
        )


@router.get("/performance-test")
async def performance_test():
    """Performance comparison between sync and async database operations"""
    import time

    try:
        db_manager = DatabaseManager()

        # Test async performance
        start_time = time.time()
        await db_manager.async_health_check()
        async_time = time.time() - start_time

        # Test sync performance
        start_time = time.time()
        db_manager.health_check()
        sync_time = time.time() - start_time

        improvement = (
            ((sync_time - async_time) / sync_time * 100)
            if sync_time > 0 else 0
        )

        return {
            "sync_operation_time": f"{sync_time:.4f}s",
            "async_operation_time": f"{async_time:.4f}s",
            "performance_improvement": f"{improvement:.2f}%",
            "recommendation": "Use async operations for better performance",
            "async_enabled": True
        }

    except Exception as e:
        logger.error(f"Performance test failed: {e}")
        return JSONResponse(
            status_code=500,
            content={
                "error": "Performance test failed",
                "details": str(e)
            }
        )
