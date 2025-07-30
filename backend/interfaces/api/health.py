"""
Health Check API Routes
======================
"""
from fastapi import APIRouter
from fastapi.responses import JSONResponse
from datetime import datetime
import logging
from redis import Redis
from rq import Queue

from infrastructure.config import get_settings
from infrastructure.database import DatabaseManager

logger = logging.getLogger(__name__)
router = APIRouter(tags=["health"])

@router.get("/health")
async def health_check():
    """Health check endpoint with real service verification"""
    try:
        settings = get_settings()
        service_status = {}
        overall_status = "healthy"
        
        # 1. Check Redis Database Connection
        try:
            db_manager = DatabaseManager()
            redis_healthy = db_manager.health_check()
            service_status["database"] = "operational" if redis_healthy else "down"
            if not redis_healthy:
                overall_status = "degraded"
        except Exception as e:
            logger.error(f"Database health check failed: {e}")
            service_status["database"] = "down"
            overall_status = "degraded"
        
        # 2. Check Redis Queue System
        try:
            redis_conn = Redis(
                host=settings.redis_host,
                port=settings.redis_port,
                password=settings.redis_password,
                decode_responses=False,
                socket_connect_timeout=3,
                socket_timeout=3
            )
            queue = Queue('default', connection=redis_conn)
            
            # Test queue connectivity by checking queue length
            queue_length = len(queue)
            service_status["queue"] = "operational"
            service_status["queue_jobs"] = queue_length
            
        except Exception as e:
            logger.error(f"Queue health check failed: {e}")
            service_status["queue"] = "down"
            overall_status = "degraded"
        
        # 3. Check Redis Connection (separate check for redundancy)
        try:
            redis_test = Redis(
                host=settings.redis_host,
                port=settings.redis_port,
                password=settings.redis_password,
                socket_connect_timeout=3,
                socket_timeout=3
            )
            redis_ping = redis_test.ping()
            service_status["redis"] = "operational" if redis_ping else "down"
            if not redis_ping:
                overall_status = "degraded"
        except Exception as e:
            logger.error(f"Redis health check failed: {e}")
            service_status["redis"] = "down"
            overall_status = "degraded"
        
        # 4. Add system information
        service_status["environment"] = settings.environment
        service_status["app_name"] = settings.app_name
        
        # Return appropriate response based on overall health
        if overall_status == "healthy":
            return {
                "status": overall_status,
                "timestamp": datetime.utcnow().isoformat(),
                "services": service_status
            }
        else:
            return JSONResponse(
                status_code=503,
                content={
                    "status": overall_status,
                    "timestamp": datetime.utcnow().isoformat(),
                    "services": service_status
                }
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
                    "queue": "unknown"
                }
            }
        )
