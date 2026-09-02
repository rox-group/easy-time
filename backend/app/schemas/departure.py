"""Departure schemas and models for Easy Time API."""

from datetime import datetime, timezone
from enum import Enum
from typing import List, Optional

from pydantic import BaseModel, Field, field_validator, model_validator


class DepartureStatus(str, Enum):
    """Status of a departure."""

    ON_TIME = "on_time"
    DELAYED = "delayed"
    EARLY = "early"
    CANCELLED = "cancelled"
    SCHEDULED = "scheduled"


class DepartureItem(BaseModel):
    """A single scheduled or real-time departure."""

    route: str = Field(
        ...,
        description="Line / Route identifier (e.g. '17', '43').",
        examples=["17", "43"],
    )
    destination: str = Field(
        ...,
        description="Headsign / destination name (e.g. 'Åkeshov', 'Hökarängen').",
        examples=["Åkeshov", "Hökarängen"],
    )
    scheduled_at: datetime = Field(
        ...,
        description="Scheduled departure time in UTC (ISO 8601).",
        examples=["2026-08-28T08:18:00Z"],
    )
    predicted_at: Optional[datetime] = Field(
        default=None,
        description="Real-time predicted departure time in UTC (ISO 8601), if available.",
        examples=["2026-08-28T08:21:00Z"],
    )
    platform: Optional[str] = Field(
        default=None,
        description="Track / platform designation (e.g. '2').",
        examples=["2", "3"],
    )
    status: DepartureStatus = Field(
        default=DepartureStatus.SCHEDULED,
        description="Current operational status of the departure.",
        examples=[DepartureStatus.DELAYED, DepartureStatus.ON_TIME],
    )
    trip_id: Optional[str] = Field(
        default=None,
        description="GTFS trip identifier.",
        examples=["14010000637189123"],
    )
    stop_id: Optional[str] = Field(
        default=None,
        description="GTFS stop identifier.",
        examples=["9022001001234001"],
    )
    stop_name: Optional[str] = Field(
        default=None,
        description="Human-readable boarding stop name.",
        examples=["Skanstull"],
    )
    delay_minutes: Optional[int] = Field(
        default=None,
        description="Calculated delay in minutes (positive for delays, negative for early).",
        examples=[3, 0],
    )
    is_realtime: bool = Field(
        default=False,
        description="True if departure has been updated with live real-time predictions.",
        examples=[True, False],
    )

    @model_validator(mode="after")
    def compute_realtime_and_delay(self) -> "DepartureItem":
        """Compute delay and realtime flag if predicted_at is available."""
        if self.predicted_at is not None:
            self.is_realtime = True
            if self.delay_minutes is None:
                delta_seconds = (self.predicted_at - self.scheduled_at).total_seconds()
                self.delay_minutes = int(round(delta_seconds / 60))

            if self.status == DepartureStatus.SCHEDULED:
                if self.delay_minutes > 0:
                    self.status = DepartureStatus.DELAYED
                elif self.delay_minutes < 0:
                    self.status = DepartureStatus.EARLY
                else:
                    self.status = DepartureStatus.ON_TIME
        return self


class DeparturesQuery(BaseModel):
    """Query parameters for fetching departures."""

    stop_id: str = Field(
        ...,
        min_length=1,
        description="Boarding stop/station identifier (required).",
        examples=["9021014001234000"],
    )
    route_id: Optional[str] = Field(
        default=None,
        description="Filter by route/line identifier (e.g. '17').",
        examples=["17"],
    )
    direction: Optional[str] = Field(
        default=None,
        description="Filter by journey direction (e.g. '0', '1', 'outbound', 'return').",
        examples=["0", "outbound"],
    )
    platform: Optional[str] = Field(
        default=None,
        description="Filter by platform / track designation.",
        examples=["2"],
    )
    destination: Optional[str] = Field(
        default=None,
        description="Filter by destination headsign (case-insensitive).",
        examples=["Åkeshov"],
    )
    limit: int = Field(
        default=10,
        ge=1,
        le=50,
        description="Maximum number of departures to return.",
    )
    time_window_minutes: int = Field(
        default=60,
        ge=5,
        le=360,
        description="Future time window in minutes to search for departures.",
    )

    @field_validator("stop_id")
    @classmethod
    def validate_stop_id_non_empty(cls, v: str) -> str:
        stripped = v.strip()
        if not stripped:
            raise ValueError("stop_id cannot be empty or whitespace only")
        return stripped


class DeparturesResponse(BaseModel):
    """Response envelope containing departures for a saved commute stop."""

    generated_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        description="UTC timestamp when this response was generated.",
        examples=["2026-08-28T08:10:00Z"],
    )
    freshness_at: Optional[datetime] = Field(
        default=None,
        description="UTC timestamp of the latest real-time data ingestion feed.",
        examples=["2026-08-28T08:09:45Z"],
    )
    stop_id: str = Field(
        ...,
        description="The queried boarding stop identifier.",
        examples=["9021014001234000"],
    )
    departures: List[DepartureItem] = Field(
        default_factory=list,
        description="List of departures matching the query criteria, ordered by departure time.",
    )
