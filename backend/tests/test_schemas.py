"""Unit tests for backend Pydantic models and serialization."""

from datetime import datetime, timezone

import pytest
from backend.app.schemas.departure import (
    DepartureItem,
    DeparturesQuery,
    DeparturesResponse,
    DepartureStatus,
)
from backend.app.schemas.health import HealthResponse
from pydantic import ValidationError


def test_departure_item_scheduled_defaults():
    """Verify default values when only scheduled departure is provided."""
    now = datetime.now(timezone.utc)
    item = DepartureItem(
        route="17",
        destination="Åkeshov",
        scheduled_at=now,
    )
    assert item.route == "17"
    assert item.destination == "Åkeshov"
    assert item.scheduled_at == now
    assert item.predicted_at is None
    assert item.status == DepartureStatus.SCHEDULED
    assert item.delay_minutes is None
    assert item.is_realtime is False


def test_departure_item_delayed_computation():
    """Verify that delay_minutes and status are computed when predicted_at is provided."""
    sched = datetime(2026, 8, 28, 8, 0, 0, tzinfo=timezone.utc)
    pred = datetime(2026, 8, 28, 8, 4, 0, tzinfo=timezone.utc)

    item = DepartureItem(
        route="43",
        destination="Hökarängen",
        scheduled_at=sched,
        predicted_at=pred,
        platform="2",
    )

    assert item.is_realtime is True
    assert item.delay_minutes == 4
    assert item.status == DepartureStatus.DELAYED
    assert item.platform == "2"


def test_departure_item_early_computation():
    """Verify early departure computation."""
    sched = datetime(2026, 8, 28, 8, 10, 0, tzinfo=timezone.utc)
    pred = datetime(2026, 8, 28, 8, 8, 0, tzinfo=timezone.utc)

    item = DepartureItem(
        route="18",
        destination="Alvik",
        scheduled_at=sched,
        predicted_at=pred,
    )

    assert item.is_realtime is True
    assert item.delay_minutes == -2
    assert item.status == DepartureStatus.EARLY


def test_departure_item_on_time_computation():
    """Verify on-time departure computation."""
    sched = datetime(2026, 8, 28, 8, 10, 0, tzinfo=timezone.utc)

    item = DepartureItem(
        route="18",
        destination="Alvik",
        scheduled_at=sched,
        predicted_at=sched,
    )

    assert item.is_realtime is True
    assert item.delay_minutes == 0
    assert item.status == DepartureStatus.ON_TIME


def test_departures_query_validation():
    """Test query model validation."""
    query = DeparturesQuery(stop_id="9021014001234000")
    assert query.stop_id == "9021014001234000"
    assert query.limit == 10
    assert query.time_window_minutes == 60
    assert query.route_id is None

    # Empty stop_id should fail
    with pytest.raises(ValidationError):
        DeparturesQuery(stop_id="")

    with pytest.raises(ValidationError):
        DeparturesQuery(stop_id="   ")

    # Invalid limit should fail
    with pytest.raises(ValidationError):
        DeparturesQuery(stop_id="123", limit=0)

    with pytest.raises(ValidationError):
        DeparturesQuery(stop_id="123", limit=100)


def test_departures_response_serialization():
    """Verify response model serialization to dict and JSON."""
    now = datetime.now(timezone.utc)
    resp = DeparturesResponse(
        generated_at=now,
        freshness_at=now,
        stop_id="9021014001234000",
        departures=[
            DepartureItem(
                route="17",
                destination="Åkeshov",
                scheduled_at=now,
                platform="2",
            )
        ],
    )

    data = resp.model_dump(mode="json")
    assert data["stop_id"] == "9021014001234000"
    assert len(data["departures"]) == 1
    assert data["departures"][0]["route"] == "17"
    assert data["departures"][0]["destination"] == "Åkeshov"
    assert data["departures"][0]["platform"] == "2"


def test_departure_item_cancelled():
    """Verify cancelled status is preserved when explicitly provided."""
    now = datetime.now(timezone.utc)
    item = DepartureItem(
        route="19",
        destination="Hässelby strand",
        scheduled_at=now,
        status=DepartureStatus.CANCELLED,
    )
    assert item.status == DepartureStatus.CANCELLED
    assert item.is_realtime is False


def test_departures_response_empty():
    """Verify empty departures list serializes cleanly."""
    now = datetime.now(timezone.utc)
    resp = DeparturesResponse(
        generated_at=now,
        stop_id="9021014001234000",
        departures=[],
    )
    data = resp.model_dump(mode="json")
    assert data["stop_id"] == "9021014001234000"
    assert data["departures"] == []
    assert data["freshness_at"] is None


def test_health_response():
    """Verify health response model."""
    health = HealthResponse(version="0.1.0", environment="test")
    assert health.status == "ok"
    assert health.version == "0.1.0"
    assert health.environment == "test"
    assert isinstance(health.timestamp, datetime)
