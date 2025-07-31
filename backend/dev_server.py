#!/usr/bin/env python3
"""
Development Server - Start the development environment
===================================================

Professional development server with comprehensive logging.
"""

import argparse
import logging
import logging.config
import os
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from logging.handlers import RotatingFileHandler


def setup_logging(
    log_level="INFO", log_file=None, max_size_mb=10, backup_count=5
):
    """Setup professional logging configuration with log rotation"""
    log_format = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"

    # Configure basic logging
    logging.basicConfig(
        level=getattr(logging, log_level.upper()),
        format=log_format,
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    # Add rotating file handler if specified
    if log_file:
        # Create logs directory if it doesn't exist
        log_dir = os.path.dirname(log_file)
        if not log_dir:
            log_dir = "logs"
        if log_dir and not os.path.exists(log_dir):
            os.makedirs(log_dir, exist_ok=True)
        
        # Setup rotating file handler
        rotating_handler = RotatingFileHandler(
            log_file,
            maxBytes=max_size_mb * 1024 * 1024,  # Convert MB to bytes
            backupCount=backup_count,
            encoding='utf-8'
        )
        rotating_handler.setLevel(logging.DEBUG)
        file_formatter = logging.Formatter(
            f"{log_format} - [PID:%(process)d]"
        )
        rotating_handler.setFormatter(file_formatter)
        logging.getLogger().addHandler(rotating_handler)
        
        # Log rotation info
        logger = logging.getLogger("dev-server")
        logger.info(
            f"Log rotation: {log_file} (max {max_size_mb}MB, "
            f"keep {backup_count})"
        )
        logger.info(
            f"Log files: {log_file}, {log_file}.1, {log_file}.2, etc."
        )


# Initialize logger
logger = logging.getLogger("dev-server")


def run_command(cmd, name, cwd=None):
    """Run a command and stream output with proper logging"""
    logger.info(f"Starting service: {name}")
    process = None
    try:
        process = subprocess.Popen(
            cmd,
            shell=True,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            universal_newlines=True,
            bufsize=1,
        )

        if process.stdout:
            for line in iter(process.stdout.readline, ""):
                # Use a separate logger for service output
                service_logger = logging.getLogger(f"service.{name.lower()}")
                service_logger.info(line.strip())

            process.stdout.close()

        return_code = process.wait()

        if return_code != 0:
            logger.error(f"Service {name} exited with code {return_code}")
        else:
            logger.info(f"Service {name} completed successfully")

    except KeyboardInterrupt:
        logger.warning(f"Stopping service: {name}")
        if process:
            process.terminate()
    except Exception as e:
        logger.error(f"Error running service {name}: {str(e)}")
        if process:
            process.terminate()


def check_requirements():
    """Check if required tools are installed"""
    logger.info("Checking system requirements...")
    requirements = {
        "python3": "python3 --version",
        "poetry": "poetry --version",
        "docker": "docker --version",
        "terraform": "terraform version",
    }

    missing = []
    for tool, cmd in requirements.items():
        try:
            result = subprocess.run(
                cmd.split(), capture_output=True, text=True
            )
            if result.returncode == 0:
                logger.info(f"Required tool found: {tool}")
            else:
                missing.append(tool)
                logger.warning(f"Required tool missing: {tool}")
        except FileNotFoundError:
            missing.append(tool)
            logger.warning(f"Required tool not found: {tool}")

    if missing:
        logger.error(f"Missing required tools: {', '.join(missing)}")
        logger.info("Installation instructions:")
        logger.info("- Poetry: https://python-poetry.org/docs/#installation")
        logger.info("- Docker: https://docs.docker.com/get-docker/")
        logger.info("- Terraform: https://www.terraform.io/downloads")
        return False

    logger.info("All system requirements satisfied")
    return True


def install_python_deps():
    """Install Python dependencies using Poetry"""
    logger.info("Installing Python dependencies with Poetry...")
    try:
        # Check if Poetry is installed
        subprocess.check_call(
            ["poetry", "--version"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

        # Install dependencies with Poetry
        subprocess.check_call(["poetry", "install"])
        logger.info("Python dependencies installed successfully with Poetry")
        return True
    except subprocess.CalledProcessError:
        logger.warning("Poetry not found, trying pip fallback...")
        try:
            # Fallback to pip install from pyproject.toml
            subprocess.check_call(
                [
                    sys.executable,
                    "-m",
                    "pip",
                    "install",
                    "-e",
                    ".",  # Install the current package in editable mode
                ]
            )
            logger.info("Python dependencies installed successfully with pip")
            return True
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to install dependencies: {e}")
            logger.info(
                "Try installing Poetry: "
                "curl -sSL https://install.python-poetry.org | python3 -"
            )
            return False


def start_redis_compose():
    """Start Redis using Docker Compose (alternative method)"""
    logger.info("Starting Redis with Docker Compose...")
    try:
        # Check if docker-compose is available
        subprocess.check_call(
            ["docker", "compose", "--version"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

        # Start Redis with Docker Compose
        subprocess.check_call(
            [
                "docker",
                "compose",
                "-f",
                "docker-compose.dev.yml",
                "up",
                "-d",
                "redis",
            ]
        )

        logger.info("Redis started successfully with Docker Compose")
        return True

    except subprocess.CalledProcessError:
        logger.warning(
            "Docker Compose not available, falling back to docker run"
        )
        return start_redis()


def stop_redis_compose():
    """Stop Redis using Docker Compose"""
    try:
        logger.info("Stopping Redis with Docker Compose...")
        subprocess.run(
            ["docker", "compose", "-f", "docker-compose.dev.yml", "down"],
            capture_output=True,
        )
        logger.info("Redis stopped successfully with Docker Compose")
    except Exception as e:
        logger.warning(f"Could not stop with Docker Compose: {e}")
        stop_redis()


def start_redis():
    """Start Redis server using Docker with proper process management"""
    logger.info("Starting Redis server with Docker...")
    container_name = "internal-platform-redis"

    try:
        # Check if container already exists and is running
        result = subprocess.run(
            ["docker", "ps", "-q", "-f", f"name={container_name}"],
            capture_output=True,
            text=True,
        )

        if result.stdout.strip():
            logger.info("Redis container is already running")
            return True

        # Check if container exists but is stopped
        result = subprocess.run(
            ["docker", "ps", "-aq", "-f", f"name={container_name}"],
            capture_output=True,
            text=True,
        )

        if result.stdout.strip():
            logger.info("Starting existing Redis container...")
            subprocess.check_call(["docker", "start", container_name])
        else:
            logger.info("Creating new Redis container...")
            # Create and start new Redis container
            subprocess.check_call(
                [
                    "docker",
                    "run",
                    "-d",
                    "--name",
                    container_name,
                    "-p",
                    "6379:6379",
                    "--restart",
                    "unless-stopped",
                    "redis:7-alpine",
                    "redis-server",
                    "--appendonly",
                    "yes",
                    "--loglevel",
                    "notice",
                ]
            )

        # Wait for Redis to be ready
        logger.info("Waiting for Redis to be ready...")
        for i in range(30):
            time.sleep(1)
            result = subprocess.run(
                ["docker", "exec", container_name, "redis-cli", "ping"],
                capture_output=True,
                text=True,
            )
            if result.returncode == 0 and "PONG" in result.stdout:
                logger.info("Redis server is ready and accepting connections")
                return True
            if i % 5 == 0:  # Log every 5 attempts to reduce noise
                logger.debug(f"Redis startup attempt {i+1}/30...")

        logger.error("Redis failed to start within 30 seconds")
        return False

    except subprocess.CalledProcessError as e:
        logger.error(f"Error managing Redis container: {e}")
        return False
    except Exception as e:
        logger.error(f"Unexpected error starting Redis: {str(e)}")
        return False


def stop_redis():
    """Stop Redis Docker container"""
    container_name = "internal-platform-redis"
    try:
        logger.info("Stopping Redis container...")
        subprocess.run(
            ["docker", "stop", container_name],
            capture_output=True,
            text=True,
        )
        logger.info("Redis container stopped successfully")
    except Exception as e:
        logger.warning(f"Could not stop Redis container: {e}")


def main():
    """Main development server startup"""
    # Parse command line arguments
    parser = argparse.ArgumentParser(
        description="Internal Platform Development Server"
    )
    parser.add_argument(
        "--log-level",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        default="INFO",
        help="Set logging level (default: INFO)",
    )
    parser.add_argument(
        "--log-file",
        help="Log to file in addition to console (supports rotation)",
    )
    parser.add_argument(
        "--log-max-size",
        type=int,
        default=10,
        help="Maximum size of log file in MB before rotation (default: 10)",
    )
    parser.add_argument(
        "--log-backup-count",
        type=int,
        default=5,
        help="Number of backup log files to keep (default: 5)",
    )
    args = parser.parse_args()

    # Setup logging with specified level and rotation settings
    setup_logging(
        args.log_level,
        args.log_file,
        args.log_max_size,
        args.log_backup_count
    )

    logger.info("=" * 60)
    logger.info("Internal Platform Development Server Starting")
    logger.info(f"Log Level: {args.log_level}")
    if args.log_file:
        logger.info(f"Log File: {args.log_file}")
        logger.info(f"Log Rotation: {args.log_max_size}MB max, "
                    f"{args.log_backup_count} backups")
    logger.info("=" * 60)

    # Check requirements
    if not check_requirements():
        logger.critical("System requirements not met. Exiting.")
        sys.exit(1)

    # Install dependencies
    if not install_python_deps():
        logger.critical("Failed to install dependencies. Exiting.")
        sys.exit(1)

    # Start Redis (try Docker Compose first, fallback to docker run)
    if not start_redis_compose():
        logger.critical("Failed to start Redis. Exiting.")
        sys.exit(1)

    logger.info("Starting development services...")

    # Create .env file if it doesn't exist
    if not os.path.exists(".env"):
        logger.info("Creating .env configuration file...")
        with open(".env", "w") as f:
            f.write(
                """# Development Environment Configuration
ENVIRONMENT=development
LOG_LEVEL=DEBUG
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
AWS_REGION=us-east-1
TERRAFORM_DIR=../terraform
"""
            )
        logger.info("Environment configuration file created successfully")

    # Commands to run
    commands = [
        {
            "cmd": "poetry run uvicorn main:app --reload --host 0.0.0.0 "
            "--port 8000",
            "name": "FastAPI-Server",
            "cwd": None,
        },
        {
            "cmd": "poetry run python worker.py",
            "name": "RQ-Worker",
            "cwd": None,
        },
        {
            "cmd": "docker logs -f internal-platform-redis",
            "name": "Redis-Logs",
            "cwd": None,
        },
    ]

    logger.info("Service endpoints:")
    logger.info("- FastAPI Server: http://localhost:8000")
    logger.info("- API Documentation: http://localhost:8000/docs")
    logger.info("- Redis: localhost:6379 (Docker container)")
    logger.info("- Redis Logs: Streaming from Docker container")
    logger.info("Use Ctrl+C to stop all services")
    logger.info("-" * 60)

    try:
        with ThreadPoolExecutor(max_workers=len(commands)) as executor:
            futures = []
            for cmd_info in commands:
                future = executor.submit(
                    run_command,
                    cmd_info["cmd"],
                    cmd_info["name"],
                    cmd_info.get("cwd"),
                )
                futures.append(future)

            # Wait for all services
            for future in futures:
                future.result()

    except KeyboardInterrupt:
        logger.info("Shutdown signal received. Stopping all services...")
        stop_redis_compose()
        logger.info("All services stopped successfully")


if __name__ == "__main__":
    main()
