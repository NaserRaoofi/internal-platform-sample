#!/bin/bash

# Development Environment Activation Script
# This script activates the Poetry environment and provides helpful commands

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Internal Developer Platform - Development Environment${NC}"
echo

# Activate the Poetry environment
echo -e "${GREEN}Activating Poetry environment...${NC}"
source .venv/bin/activate

# Export Poetry path for convenience
export POETRY_BIN="/home/sirwan/ec22/.venv/bin/poetry"

echo -e "${GREEN}✅ Environment activated!${NC}"
echo
echo -e "${YELLOW}Available commands:${NC}"
echo "  poetry run uvicorn backend.main:app --reload     # Start backend API"
echo "  poetry run python ui/app.py                      # Start frontend UI"  
echo "  poetry run python -m pytest tests/              # Run tests"
echo "  poetry run black backend/ ui/                    # Format code"
echo "  poetry run isort backend/ ui/                    # Sort imports"
echo "  ./scripts/watch.sh                               # Watch queue"
echo "  ./scripts/demo.sh                                # Run demo"
echo
echo -e "${BLUE}Project URLs:${NC}"
echo "  Backend API: http://localhost:8000"
echo "  API Docs: http://localhost:8000/docs"  
echo "  Frontend UI: http://localhost:8080"
echo
echo -e "${YELLOW}To deactivate: ${NC}deactivate"
echo
