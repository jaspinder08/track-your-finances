from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from config.settings import settings

engine = create_engine(
    settings.DB_CONNECTION,
    pool_pre_ping=True,
) if settings.DB_CONNECTION else None

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
) if engine else None


def get_db():
    if SessionLocal is None:
        raise RuntimeError("Database connection is not configured.")
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
