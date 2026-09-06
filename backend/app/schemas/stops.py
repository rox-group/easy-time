"""Pydantic models for GTFS stops and search queries."""

from typing import List, Optional

from pydantic import BaseModel, Field


class StopItem(BaseModel):
    """Normalized public transport stop/station item."""

    stop_id: str = Field(..., description="Unique GTFS stop identifier")
    stop_name: str = Field(..., description="Name of the stop or station")
    platform_code: Optional[str] = Field(
        None, description="Platform number or letter if applicable"
    )
    parent_station: Optional[str] = Field(
        None, description="Parent station stop ID if part of a complex"
    )
    stop_lat: Optional[float] = Field(None, description="Latitude coordinate")
    stop_lon: Optional[float] = Field(None, description="Longitude coordinate")


class StopsResponse(BaseModel):
    """Response containing matching stops."""

    query: Optional[str] = Field(None, description="The search term used")
    count: int = Field(..., description="Number of results returned")
    stops: List[StopItem] = Field(..., description="List of matching transit stops")

