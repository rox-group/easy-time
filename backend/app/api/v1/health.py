"""Health check endpoints."""

from backend.app.core.config import settings
from backend.app.schemas.health import HealthResponse
from fastapi import APIRouter, status

router = APIRouter()


@router.get(
    "/health",
    response_model=HealthResponse,
    status_code=status.HTTP_200_OK,
    summary="Health Check",
    description="Returns service health status, application version, and environment.",
)
async def get_health() -> HealthResponse:
    """Return application health information."""
    return HealthResponse(
        status="ok",
        version=settings.VERSION,
        environment=settings.ENVIRONMENT,
    )
