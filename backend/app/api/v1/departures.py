"""Departures endpoint implementation."""

from datetime import datetime, timedelta, timezone
from typing import List, Optional

from backend.app.schemas.departure import (
    DepartureItem,
    DeparturesQuery,
    DeparturesResponse,
)
from backend.app.schemas.error import ErrorResponse
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



def _generate_sample_departures(query: DeparturesQuery, base_time: datetime) -> List[DepartureItem]:
    """Generate sample departure items for contract verification and development."""
    sample_pool = [
        {
            "route": "17",
            "destination": "Åkeshov",
            "minutes_offset": 8,
            "delay_minutes": None,
            "platform": "2",
            "direction": "0",
            "trip_id": "14010000637189101",
        },
        {
            "route": "18",
            "destination": "Alvik",
            "minutes_offset": 14,
            "delay_minutes": 3,
            "platform": "2",
            "direction": "0",
            "trip_id": "14010000637189102",
        },
        {
            "route": "19",
            "destination": "Hässelby strand",
            "minutes_offset": 20,
            "delay_minutes": None,
            "platform": "2",
            "direction": "0",
            "trip_id": "14010000637189103",
        },
        {
            "route": "17",
            "destination": "Skarpnäck",
            "minutes_offset": 6,
            "delay_minutes": None,
            "platform": "3",
            "direction": "1",
            "trip_id": "14010000637189104",
        },
        {
            "route": "18",
            "destination": "Farsta strand",
            "minutes_offset": 12,
            "delay_minutes": None,
            "platform": "3",
            "direction": "1",
            "trip_id": "14010000637189105",
        },
        {
            "route": "19",
            "destination": "Hagsätra",
            "minutes_offset": 18,
            "delay_minutes": 2,
            "platform": "3",
            "direction": "1",
            "trip_id": "14010000637189106",
        },
    ]

    items: List[DepartureItem] = []
    for item in sample_pool:
        # Apply route filter
        if query.route_id and item["route"] != query.route_id:
            continue
        # Apply platform filter
        if query.platform and item["platform"] != query.platform:
            continue
        # Apply destination filter
        if query.destination and query.destination.lower() not in item["destination"].lower():
            continue
        # Apply direction filter
        if query.direction:
            normalized_dir = query.direction.lower()
            if normalized_dir in ("0", "outbound") and item["direction"] != "0":
                continue
            if normalized_dir in ("1", "return") and item["direction"] != "1":
                continue

        # Check time window
        if item["minutes_offset"] > query.time_window_minutes:
            continue

        sched_at = base_time + timedelta(minutes=item["minutes_offset"])
        pred_at = None
        if item["delay_minutes"] is not None:
            pred_at = sched_at + timedelta(minutes=item["delay_minutes"])

        items.append(
            DepartureItem(
                route=item["route"],
                destination=item["destination"],
                scheduled_at=sched_at,
                predicted_at=pred_at,
                platform=item["platform"],
                trip_id=item["trip_id"],
                stop_id=query.stop_id,
            )
        )

        if len(items) >= query.limit:
            break

    return items


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
) -> DeparturesResponse:
    """Fetch departures for a given stop with optional filters."""
    now = datetime.now(timezone.utc)
    freshness = now - timedelta(seconds=15)
    departures = _generate_sample_departures(query, now)

    return DeparturesResponse(
        generated_at=now,
        freshness_at=freshness,
        stop_id=query.stop_id,
        departures=departures,
    )
