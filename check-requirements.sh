#!/bin/bash

# System Requirements Check Script
# ================================
# This script checks if all required system dependencies are installed

echo "🔍 Checking system requirements for Internal Platform Sample..."
echo

# Function to check if command exists
check_command() {
    if command -v "$1" &> /dev/null; then
        echo "✅ $1: $(command -v "$1")"
        if [ "$1" = "terraform" ]; then
            echo "   Version: $(terraform --version | head -n1)"
        elif [ "$1" = "python3" ]; then
            echo "   Version: $(python3 --version)"
        elif [ "$1" = "node" ]; then
            echo "   Version: $(node --version)"
        elif [ "$1" = "redis-server" ]; then
            echo "   Version: $(redis-server --version | head -n1)"
        fi
    else
        echo "❌ $1: Not found"
        return 1
    fi
    echo
}

# Check system dependencies
echo "📋 System Dependencies:"
echo "----------------------"

failed=0

check_command "python3" || failed=1
check_command "pip3" || failed=1
check_command "node" || failed=1
check_command "npm" || failed=1
check_command "redis-server" || failed=1
check_command "terraform" || failed=1

# Check optional dependencies
echo "🔧 Optional Dependencies:"
echo "------------------------"
check_command "aws" && echo "   AWS CLI is available for cloud deployments" || echo "⚠️  AWS CLI not found (optional, but recommended)"
echo

# Check Python environment
echo "🐍 Python Environment Check:"
echo "----------------------------"
if [ -d "backend/venv" ]; then
    echo "✅ Virtual environment exists at backend/venv"
else
    echo "⚠️  Virtual environment not found. Run: cd backend && python3 -m venv venv"
fi
echo

# Check Node modules
echo "📦 Node.js Dependencies Check:"
echo "------------------------------"
if [ -d "ui/node_modules" ]; then
    echo "✅ Node modules installed in ui/"
else
    echo "⚠️  Node modules not found. Run: cd ui && npm install"
fi
echo

# Check Redis status
echo "🔴 Redis Service Check:"
echo "----------------------"
if pgrep redis-server > /dev/null; then
    echo "✅ Redis server is running"
else
    echo "⚠️  Redis server is not running. Start with: sudo systemctl start redis-server"
fi
echo

# Summary
if [ $failed -eq 0 ]; then
    echo "🎉 All required system dependencies are installed!"
    echo "📖 See SETUP.md for detailed setup instructions."
else
    echo "❌ Some required dependencies are missing."
    echo "📖 Please install missing dependencies. See SETUP.md for instructions."
    exit 1
fi

echo
echo "🚀 Next steps:"
echo "1. Follow SETUP.md for detailed setup instructions"
echo "2. Configure environment files (.env)"
echo "3. Start the services as described in SETUP.md"
echo "4. Access the UI at http://localhost:3000"
