"""API v1 endpoint for searching public transport stops."""

from typing import Optional

from backend.app.schemas.stops import StopsResponse
from backend.app.services.stops_service import StopsService, stops_service
from fastapi import APIRouter, Depends, Query, status

router = APIRouter()


def _get_stops_service() -> StopsService:
    """Dependency provider for stops service."""
    return stops_service


@router.get(
    "/stops",
    response_model=StopsResponse,
    status_code=status.HTTP_200_OK,
    summary="Search transit stops",
    description="Search for Stockholm transit stops and stations by name or stop ID.",
)
async def search_stops(
    query: Optional[str] = Query(
        None, description="Search query matching stop or station name"
    ),
    limit: int = Query(20, ge=1, le=100, description="Maximum number of stops to return"),
    service: StopsService = Depends(_get_stops_service),
) -> StopsResponse:
    """Search public transport stops."""
    return await service.search_stops(query=query, limit=limit)

