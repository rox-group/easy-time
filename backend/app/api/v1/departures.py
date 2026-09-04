"""Departures endpoint implementation."""

from typing import Optional

from backend.app.schemas.departure import (
    DeparturesQuery,
    DeparturesResponse,
)
from backend.app.schemas.error import ErrorResponse
from backend.app.services.departure_service import DepartureService, departure_service
from fastapi import APIRouter, Depends, HTTPException, Query, status

router = APIRouter()


def _get_departures_query(
    stop_id: str = Query(
        ...,
        min_length=1,
        description="Boarding stop/station identifier (required).",
        examples=["9021014001234000"],
    ),
    route_id: Optional[str] = Query(
        default=None,
        description="Filter by route/line identifier (e.g. '17', '43').",
        examples=["17"],
    ),
    direction: Optional[str] = Query(
        default=None,
        description="Filter by journey direction ('0', '1', 'outbound', 'return').",
        examples=["0"],
    ),
    platform: Optional[str] = Query(
        default=None,
        description="Filter by platform/track designation (e.g. '2').",
        examples=["2"],
    ),
    destination: Optional[str] = Query(
        default=None,
        description="Filter by destination headsign name (case-insensitive substring).",
        examples=["Åkeshov"],
    ),
    limit: int = Query(
        default=10,
        ge=1,
        le=50,
        description="Maximum number of departures to return.",
    ),
    time_window_minutes: int = Query(
        default=60,
        ge=5,
        le=360,
        description="Future time window in minutes to search for departures.",
    ),
) -> DeparturesQuery:
    """Dependency validator for departure query parameters."""
    cleaned_stop_id = stop_id.strip()
    if not cleaned_stop_id:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="stop_id cannot be empty or whitespace only",
        )
    return DeparturesQuery(
        stop_id=cleaned_stop_id,
        route_id=route_id,
        direction=direction,
        platform=platform,
        destination=destination,
        limit=limit,
        time_window_minutes=time_window_minutes,
    )


def _get_departure_service() -> DepartureService:
    """Dependency provider for departure service."""
    return departure_service


@router.get(
    "/departures",
    response_model=DeparturesResponse,
    status_code=status.HTTP_200_OK,
    summary="Get saved-commute departures",
    description=(
        "Retrieves upcoming scheduled and real-time departures for a specific boarding stop. "
        "Allows filtering by route/line, platform, destination, and journey direction."
    ),
    responses={
        200: {"description": "Successful retrieval of departures.", "model": DeparturesResponse},
        422: {"description": "Validation error in query parameters.", "model": ErrorResponse},
    },
)
async def get_departures(
    query: DeparturesQuery = Depends(_get_departures_query),
    service: DepartureService = Depends(_get_departure_service),
) -> DeparturesResponse:
    """Fetch departures for a given stop with optional filters."""
    return await service.get_departures(query)
