import logging
from sqlalchemy import text
from config.settings import settings
from db.session import engine
from db.base import Base

logger = logging.getLogger("db")


def mask_db_url(url: str) -> str:
    if not url:
        return ""
    try:
        from urllib.parse import urlparse
        parsed = urlparse(url)
        if parsed.password:
            masked = url.replace(f":{parsed.password}@", ":***@")
            return masked
        elif parsed.username:
            # Check if there is username: format with empty password
            if f"{parsed.username}:@" in url:
                return url.replace(f"{parsed.username}:@", f"{parsed.username}:***@")
    except Exception:
        pass
    return url


def init_db() -> None:
    if not engine:
        logger.warning("Database engine not initialized.")
        return

    db_url_masked = mask_db_url(settings.DB_CONNECTION)
    try:
        with engine.connect() as connection:
            # Get current database name
            result = connection.execute(text("SELECT current_database();"))
            db_name = result.scalar()
            logger.info(f"Database connected: {db_name}")
            logger.info(f"Postgres URL: {db_url_masked}")

            # Create tables if not present
            Base.metadata.create_all(bind=engine)
            table_count = len(Base.metadata.tables)
            logger.info(f"Postgres tables ready: {table_count} model tables configured")
    except Exception as e:
        logger.error(f"Database connection error: {e}")
