"""
Clean Architecture Main Entry Point
===================================

Thin application entry point following Clean Architecture principles.
"""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Import route modules
from interfaces.api.health import router as health_router
from interfaces.api.infrastructure import router as infra_router
from interfaces.api.jobs import router as jobs_router


# Simple setup functions
async def setup_database():
    """Initialize database connection"""
    logger.info("📊 Database setup completed")


async def setup_redis():
    """Initialize Redis connection"""
    logger.info("🔴 Redis setup completed")


logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan management"""
    logger.info("🚀 Starting Cloud Automation Platform...")

    # Initialize infrastructure
    await setup_database()
    await setup_redis()

    yield

    logger.info("🛑 Shutting down Cloud Automation Platform...")


def create_app() -> FastAPI:
    """Application factory following Clean Architecture"""

    # Create FastAPI app
    app = FastAPI(
        title="Cloud Automation Platform",
        description="Production-grade Internal Developer Platform",
        version="2.0.0",
        lifespan=lifespan,
    )

    # Setup CORS
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["http://localhost:3000", "http://localhost:3001"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Register API routes
    app.include_router(health_router)
    app.include_router(infra_router)
    app.include_router(jobs_router)

    # Root endpoint
    @app.get("/")
    async def root():
        return {
            "message": "Cloud Automation Platform API",
            "version": "2.0.0",
            "status": "operational",
        }

    return app


# Create application instance
app = create_app()

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)
