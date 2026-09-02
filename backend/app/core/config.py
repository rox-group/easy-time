"""Application configuration."""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Easy Time backend application settings."""

    PROJECT_NAME: str = "Easy Time API"
    VERSION: str = "0.1.0"
    API_V1_STR: str = "/v1"
    ENVIRONMENT: str = "development"
    DOCS_URL: str = "/docs"
    OPENAPI_URL: str = "/openapi.json"

    model_config = SettingsConfigDict(
        case_sensitive=True,
        env_file=".env",
        extra="ignore",
    )



settings = Settings()
