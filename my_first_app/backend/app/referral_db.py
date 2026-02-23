"""
Database initialization and session management for Problem B referral system.
"""
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from .database_models import Base

def _is_postgres_url(db_url: str) -> bool:
    normalized = (db_url or "").strip().lower()
    return normalized.startswith("postgresql://") or normalized.startswith("postgres://")


def _require_postgres_url(db_url: str) -> str:
    if not _is_postgres_url(db_url):
        raise RuntimeError(
            "REFERRAL_DATABASE_URL must be a PostgreSQL URL, for example "
            "'postgresql://postgres:postgres@127.0.0.1:5432/ecd_data'."
        )
    return db_url


# Database URL (PostgreSQL-only)
DATABASE_URL = _require_postgres_url(
    os.getenv(
        "REFERRAL_DATABASE_URL",
        os.getenv(
            "ECD_DATABASE_URL",
            os.getenv(
                "DATABASE_URL",
                "postgresql://postgres:postgres@127.0.0.1:5432/ecd_data",
            ),
        ),
    )
)

# Create engine
engine = create_engine(
    DATABASE_URL,
    echo=False,
    pool_pre_ping=True,
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
