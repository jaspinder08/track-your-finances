from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    PROJECT_NAME: str = "TYF - Track Your Finances"
    API_V1_STR: str = "/v1"
    DB_CONNECTION: str = "postgresql://postgres:@localhost:5432/tyf"

    model_config = SettingsConfigDict(
        env_file=(str(BASE_DIR / ".env"), ".env"),
        extra="ignore",
        case_sensitive=False,
    )


settings = Settings()

