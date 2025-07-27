"""
Main Application - Composition root and application startup.

This file composes all the layers of the Clean Architecture and
starts the FastAPI application.
"""

import uvicorn
from backend.presentation.api import app

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
