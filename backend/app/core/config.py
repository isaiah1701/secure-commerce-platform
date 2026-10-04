from functools import lru_cache

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Secure Commerce Platform"
    environment: str = "development"
    database_url: str = "postgresql+psycopg://commerce:commerce@db:5432/commerce"
    jwt_secret: str = "local-development-only-change-me-please"
    jwt_algorithm: str = "HS256"
    jwt_expiration_minutes: int = 60
    log_level: str = "INFO"
    cors_origins: list[str] = ["http://localhost:5173", "http://localhost:8080"]
    login_max_attempts: int = 5
    login_lock_minutes: int = 15
    auth_rate_limit: int = 10
    auth_rate_window_seconds: int = 60

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @field_validator("cors_origins", mode="before")
    @classmethod
    def parse_origins(cls, value):
        if isinstance(value, str):
            return [origin.strip() for origin in value.split(",") if origin.strip()]
        return value


@lru_cache
def get_settings() -> Settings:
    return Settings()
