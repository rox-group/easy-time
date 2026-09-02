"""Health check schema."""

from datetime import datetime, timezone

from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    """Health check response."""

    status: str = Field(
        default="ok",
        description="Service health status.",
        examples=["ok"],
    )
    version: str = Field(
        default="0.1.0",
        description="Application version.",
        examples=["0.1.0"],
    )
    environment: str = Field(
        default="development",
        description="Current environment.",
        examples=["development"],
    )
    timestamp: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        description="Current server UTC timestamp.",
        examples=["2026-09-02T08:00:00Z"],
    )

