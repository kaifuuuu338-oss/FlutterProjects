"""
Database initialization and session management for Problem B referral system.
"""
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from .database_models import Base

# Database URL
DATABASE_URL = os.getenv(
    "REFERRAL_DATABASE_URL",
    "postgresql+psycopg2://localhost:5432/referral_system"
)

# Create engine
engine = create_engine(
    DATABASE_URL,
    echo=False
)

# Session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db() -> Session:
    """Dependency injection for database session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    """Initialize database - create all tables."""
    Base.metadata.create_all(bind=engine)


def reset_db():
    """Drop all tables and recreate (for testing)."""
    Base.metadata.drop_all(bind=engine)
    init_db()
