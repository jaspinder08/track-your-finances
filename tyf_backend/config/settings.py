from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    PROJECT_NAME: str = "tyfbackend"
    API_V1_STR: str = "/v1"
    DB_CONNECTION: str = "postgresql://postgres:@localhost:5432/tyf"

    model_config = SettingsConfigDict(
        env_file=".env",
        extra="ignore",
        case_sensitive=False,
    )


settings = Settings()
