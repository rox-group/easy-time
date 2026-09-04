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

    # GTFS & Trafiklab Settings
    TRAFIKLAB_API_KEY: str = ""
    TRAFIKLAB_GTFS_STATIC_URL: str = (
        "https://opendata.samtrafiken.se/gtfs-regional/sl/sl.zip"
    )
    TRAFIKLAB_GTFS_RT_TRIP_UPDATES_URL: str = (
        "https://opendata.samtrafiken.se/gtfs-rt/sl/TripUpdates.pb"
    )
    GTFS_DB_PATH: str = "backend/data/gtfs.db"
    GTFS_RT_POLL_INTERVAL_SECONDS: int = 30
    GTFS_RT_CACHE_TTL_SECONDS: int = 60

    model_config = SettingsConfigDict(
        case_sensitive=True,
        env_file=".env",
        extra="ignore",
    )


settings = Settings()
