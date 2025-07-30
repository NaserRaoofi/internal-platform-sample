#!/usr/bin/env python3
"""
Database initialization script for Internal Platform
Creates tables and initial data for the hybrid SQLite + Redis architecture
"""

import asyncio
import hashlib
import logging
from datetime import datetime
from pathlib import Path

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import text

from infrastructure.config import get_settings
from infrastructure.models import Base, User
from domain.models import UserRole

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

async def create_database():
    """Create database tables"""
    settings = get_settings()
    
    # Create the database file if it doesn't exist
    db_path = Path("./internal_platform.db")
    if not db_path.exists():
        db_path.touch()
        logger.info(f"Created database file: {db_path.absolute()}")
    
    # Create async engine
    engine = create_async_engine(
        settings.database_url,
        echo=True  # Log SQL statements
    )
    
    logger.info("Creating database tables...")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    logger.info("✅ Database tables created successfully!")
    return engine

async def create_initial_users(engine):
    """Create initial admin and developer users"""
    
    # Create session factory
    async_session = sessionmaker(
        bind=engine,
        class_=AsyncSession,
        expire_on_commit=False
    )
    
    async with async_session() as session:
        # Check if users already exist
        result = await session.execute(text("SELECT COUNT(*) FROM users"))
        user_count = result.scalar()
        
        if user_count > 0:
            logger.info("👥 Users already exist, skipping creation")
            return
        
        logger.info("Creating initial users...")
        
        # Create admin user (admin/admin)
        admin_password_hash = hashlib.sha256("admin".encode()).hexdigest()
        admin_user = User(
            username="admin",
            email="admin@internal-platform.local",
            password_hash=admin_password_hash,
            role=UserRole.ADMIN,
            is_active=True,
            created_at=datetime.utcnow()
        )
        
        # Create developer user (user1/user1)  
        dev_password_hash = hashlib.sha256("user1".encode()).hexdigest()
        dev_user = User(
            username="user1",
            email="user1@internal-platform.local",
            password_hash=dev_password_hash,
            role=UserRole.DEVELOPER,
            is_active=True,
            created_at=datetime.utcnow()
        )
        
        # Add users to session
        session.add(admin_user)
        session.add(dev_user)
        
        # Commit changes
        await session.commit()
        
        logger.info("✅ Created initial users:")
        logger.info("   👑 Admin: admin/admin (ADMIN role)")
        logger.info("   👨‍💻 Developer: user1/user1 (DEVELOPER role)")

async def verify_installation():
    """Verify database setup is working"""
    settings = get_settings()
    engine = create_async_engine(settings.database_url)
    
    async_session = sessionmaker(
        bind=engine,
        class_=AsyncSession,
        expire_on_commit=False
    )
    
    async with async_session() as session:
        # Count users
        result = await session.execute(text("SELECT COUNT(*) FROM users"))
        user_count = result.scalar()
        
        # List users
        result = await session.execute(text("SELECT username, role FROM users"))
        users = result.fetchall()
        
        logger.info(f"📊 Database verification:")
        logger.info(f"   Total users: {user_count}")
        for username, role in users:
            logger.info(f"   - {username} ({role})")
    
    await engine.dispose()

async def main():
    """Main initialization function"""
    logger.info("🚀 Starting Internal Platform database initialization...")
    
    try:
        # Create database and tables
        engine = await create_database()
        
        # Create initial users
        await create_initial_users(engine)
        
        # Verify installation
        await verify_installation()
        
        # Cleanup
        await engine.dispose()
        
        logger.info("🎉 Database initialization completed successfully!")
        logger.info("")
        logger.info("You can now start the server with:")
        logger.info("  cd backend && source venv/bin/activate && python main.py")
        logger.info("")
        logger.info("Login credentials:")
        logger.info("  Admin: admin/admin")
        logger.info("  Developer: user1/user1")
        
    except Exception as e:
        logger.error(f"❌ Database initialization failed: {e}")
        logger.exception("Full error details:")
        exit(1)

if __name__ == "__main__":
    asyncio.run(main())
