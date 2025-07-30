#!/bin/bash
# Virtual Environment Activation Script
# ====================================

echo "🚀 Activating Python Virtual Environment..."
echo "📁 Project: Internal Platform Backend"
echo "🐍 Python: $(poetry run python --version)"
echo ""

# Activate virtual environment
source .venv/bin/activate

# Update PATH for Poetry
export PATH="$HOME/.local/bin:$PATH"

echo "✅ Virtual environment activated!"
echo "💡 You can now run:"
echo "   python main.py       # Start the FastAPI server"
echo "   python -m pytest     # Run tests"
echo "   python init_db.py    # Initialize database"
echo ""
echo "📦 Key packages available:"
echo "   - FastAPI $(python -c 'import fastapi; print(fastapi.__version__)')"
echo "   - SQLAlchemy $(python -c 'import sqlalchemy; print(sqlalchemy.__version__)')"
echo "   - Redis $(python -c 'import redis; print(redis.__version__)')"
echo ""

# Change shell prompt to show virtual environment
export PS1="(venv) $PS1"
