# Makefile for Internal Platform Development
# ==========================================

.PHONY: help install format lint test clean setup-dev

# Default target
help:
	@echo "🚀 Internal Platform Development Commands"
	@echo "========================================="
	@echo ""
	@echo "setup-dev     Setup development environment"
	@echo "install       Install dependencies"
	@echo "format        Format code with Black and isort"
	@echo "lint          Run linting checks"
	@echo "test          Run tests"
	@echo "clean         Clean temporary files"
	@echo "check         Run all checks (format + lint + test)"
	@echo ""

# Setup development environment
setup-dev:
	@echo "🔧 Setting up development environment..."
	cd backend && python -m venv .venv
	cd backend && .venv/bin/pip install --upgrade pip
	cd backend && .venv/bin/pip install poetry
	cd backend && .venv/bin/poetry install
	cd backend && .venv/bin/pip install pre-commit black isort flake8 mypy
	.venv/bin/pre-commit install
	@echo "✅ Development environment ready!"

# Install dependencies
install:
	cd backend && .venv/bin/poetry install
	cd ui && npm install

# Format code
format:
	@echo "🎨 Formatting Python code..."
	cd backend && .venv/bin/black . --line-length 88
	cd backend && .venv/bin/isort . --profile black --line-length 88
	@echo "✅ Code formatting complete!"

# Run linting
lint:
	@echo "🔍 Running linting checks..."
	cd backend && .venv/bin/flake8 . --max-line-length=88 --extend-ignore=E203,W503,E501,W291,W293,E302,E305 --per-file-ignores=__init__.py:F401
	@echo "✅ Linting complete!"

# Run tests
test:
	@echo "🧪 Running tests..."
	cd backend && .venv/bin/python -m pytest tests/ -v
	cd ui && npm test
	@echo "✅ Tests complete!"

# Clean temporary files
clean:
	@echo "🧹 Cleaning temporary files..."
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete
	find . -type d -name "*.egg-info" -exec rm -rf {} +
	find . -type f -name ".coverage" -delete
	@echo "✅ Cleanup complete!"

# Run all checks
check: format lint test
	@echo "🎉 All checks passed!"

# Start development servers
dev-backend:
	@echo "🚀 Starting backend server..."
	cd backend && .venv/bin/python main.py

dev-frontend:
	@echo "🚀 Starting frontend server..."
	cd ui && npm start

dev-worker:
	@echo "🚀 Starting background worker..."
	cd backend && .venv/bin/python -m application.worker
