#!/usr/bin/env python3
"""
Development Server - Start the development environment
===================================================

Quick start script for local development.
"""

import subprocess
import sys
import os
import time
from concurrent.futures import ThreadPoolExecutor

def run_command(cmd, name, cwd=None):
    """Run a command and stream output"""
    print(f"Starting {name}...")
    try:
        process = subprocess.Popen(
            cmd,
            shell=True,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            universal_newlines=True,
            bufsize=1
        )
        
        for line in iter(process.stdout.readline, ''):
            print(f"[{name}] {line}", end='')
        
        process.stdout.close()
        return_code = process.wait()
        
        if return_code != 0:
            print(f"❌ {name} exited with code {return_code}")
        else:
            print(f"✅ {name} completed successfully")
            
    except KeyboardInterrupt:
        print(f"\n🛑 Stopping {name}...")
        process.terminate()
    except Exception as e:
        print(f"❌ Error running {name}: {str(e)}")

def check_requirements():
    """Check if required tools are installed"""
    requirements = {
        'python3': 'python3 --version',
        'redis-server': 'redis-server --version',
        'terraform': 'terraform version'
    }
    
    missing = []
    for tool, cmd in requirements.items():
        try:
            result = subprocess.run(cmd.split(), capture_output=True, text=True)
            if result.returncode == 0:
                print(f"✅ {tool}: Found")
            else:
                missing.append(tool)
        except FileNotFoundError:
            missing.append(tool)
    
    if missing:
        print(f"❌ Missing required tools: {', '.join(missing)}")
        print("\nInstallation instructions:")
        print("- Redis: https://redis.io/download")
        print("- Terraform: https://www.terraform.io/downloads")
        return False
    
    return True

def install_python_deps():
    """Install Python dependencies"""
    print("📦 Installing Python dependencies...")
    try:
        subprocess.check_call([
            sys.executable, "-m", "pip", "install", "-r", "requirements.txt"
        ])
        print("✅ Python dependencies installed")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to install dependencies: {e}")
        return False

def start_redis():
    """Start Redis server"""
    print("🚀 Starting Redis server...")
    try:
        # Check if Redis is already running
        result = subprocess.run(['redis-cli', 'ping'], capture_output=True, text=True)
        if result.returncode == 0:
            print("✅ Redis is already running")
            return True
        
        # Start Redis server
        subprocess.Popen(['redis-server'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        # Wait for Redis to start
        for i in range(10):
            time.sleep(1)
            result = subprocess.run(['redis-cli', 'ping'], capture_output=True, text=True)
            if result.returncode == 0:
                print("✅ Redis server started")
                return True
        
        print("❌ Redis failed to start")
        return False
        
    except Exception as e:
        print(f"❌ Error starting Redis: {str(e)}")
        return False

def main():
    """Main development server startup"""
    print("🚀 Internal Platform Development Server")
    print("=" * 50)
    
    # Check requirements
    if not check_requirements():
        sys.exit(1)
    
    # Install dependencies
    if not install_python_deps():
        sys.exit(1)
    
    # Start Redis
    if not start_redis():
        sys.exit(1)
    
    print("\n🎯 Starting development services...")
    
    # Create .env file if it doesn't exist
    if not os.path.exists('.env'):
        with open('.env', 'w') as f:
            f.write("""# Development Environment Configuration
ENVIRONMENT=development
LOG_LEVEL=DEBUG
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
AWS_REGION=us-east-1
TERRAFORM_DIR=../terraform
""")
        print("✅ Created .env file")
    
    # Commands to run
    commands = [
        {
            'cmd': 'python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000',
            'name': 'FastAPI-Server',
            'cwd': None
        },
        {
            'cmd': 'python worker.py',
            'name': 'RQ-Worker',
            'cwd': None
        }
    ]
    
    print("\n📡 Services starting:")
    print("- FastAPI Server: http://localhost:8000")
    print("- API Docs: http://localhost:8000/docs")
    print("- Redis: localhost:6379")
    print("\n🔄 Use Ctrl+C to stop all services")
    print("-" * 50)
    
    try:
        with ThreadPoolExecutor(max_workers=len(commands)) as executor:
            futures = []
            for cmd_info in commands:
                future = executor.submit(
                    run_command, 
                    cmd_info['cmd'], 
                    cmd_info['name'],
                    cmd_info.get('cwd')
                )
                futures.append(future)
            
            # Wait for all services
            for future in futures:
                future.result()
                
    except KeyboardInterrupt:
        print("\n🛑 Shutting down development server...")
        print("✅ All services stopped")

if __name__ == "__main__":
    main()
