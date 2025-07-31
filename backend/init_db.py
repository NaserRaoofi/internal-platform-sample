#!/usr/bin/env python3
"""
Database initialization script for Internal Platform
Creates tables and initial data for the hybrid SQLite + Redis architecture
"""

import hashlib
import logging
from datetime import datetime
from pathlib import Path

from infrastructure.database import sqlite_manager
from infrastructure.models import User

# Setup logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


def create_database():
    """Create database tables"""
    # Create the database file if it doesn't exist
    db_path = Path("./internal_platform.db")
    if not db_path.exists():
        db_path.touch()
        logger.info(f"Created database file: {db_path.absolute()}")

    logger.info("Creating database tables...")
    sqlite_manager.create_tables()
    logger.info("✅ Database tables created successfully!")


def create_initial_users():
    """Create initial admin and developer users"""
    with sqlite_manager.get_session() as session:
        # Check if users already exist
        existing_users = session.query(User).count()

        if existing_users > 0:
            logger.info("👥 Users already exist, skipping creation")
            return

        logger.info("Creating initial users...")

        # Create admin user (admin/admin)
        admin_password_hash = hashlib.sha256("admin".encode()).hexdigest()
        admin_user = User(
            username="admin",
            email="admin@internal-platform.local",
            password_hash=admin_password_hash,
            role="admin",
            is_active=True,
            created_at=datetime.utcnow(),
        )

        # Create developer user (user1/user1)
        dev_password_hash = hashlib.sha256("user1".encode()).hexdigest()
        dev_user = User(
            username="user1",
            email="user1@internal-platform.local",
            password_hash=dev_password_hash,
            role="developer",
            is_active=True,
            created_at=datetime.utcnow(),
        )

        # Add users to session
        session.add(admin_user)
        session.add(dev_user)

        # Commit changes
        session.commit()

        logger.info("✅ Created initial users:")
        logger.info("   👑 Admin: admin/admin (ADMIN role)")
        logger.info("   👨‍💻 Developer: user1/user1 (DEVELOPER role)")


def verify_installation():
    """Verify database setup is working"""
    with sqlite_manager.get_session() as session:
        # Count users
        user_count = session.query(User).count()

        # List users
        users = session.query(User.username, User.role).all()

        logger.info("📊 Database verification:")
        logger.info(f"   Total users: {user_count}")
        for username, role in users:
            logger.info(f"   - {username} ({role})")


def main():
    """Main initialization function"""
    logger.info("🚀 Starting Internal Platform database initialization...")

    try:
        # Create database and tables
        create_database()

        # Create initial users
        create_initial_users()

        # Verify installation
        verify_installation()

        logger.info("🎉 Database initialization completed successfully!")
        logger.info("")
        logger.info("You can now start the server with:")
        logger.info("  poetry run python main.py")
        logger.info("")
        logger.info("Login credentials:")
        logger.info("  Admin: admin/admin")
        logger.info("  Developer: user1/user1")

    except Exception as e:
        logger.error(f"❌ Database initialization failed: {e}")
        logger.exception("Full error details:")
        exit(1)


if __name__ == "__main__":
    main()
