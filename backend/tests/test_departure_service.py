"""Unit and integration tests for DepartureService resolution."""

from datetime import datetime, timezone

import pytest
from backend.app.db.database import DatabaseManager
from backend.app.schemas.departure import DeparturesQuery, DepartureStatus
from backend.app.services.departure_service import DepartureService
from backend.app.services.gtfs_realtime import GTFSRealtimeService
from backend.app.services.gtfs_static import GTFSStaticImporter
from backend.tests.fixtures.gtfs_fixtures import (
    create_sample_gtfs_rt_protobuf,
    create_sample_gtfs_zip,
)


@pytest.fixture
def populated_departure_service(tmp_path):
    """Fixture providing a departure service backed by an SQLite DB loaded with sample GTFS data."""
    test_db_path = str(tmp_path / "test_departures.db")
    db = DatabaseManager(db_path=test_db_path)
    importer = GTFSStaticImporter(db=db)
    importer.import_from_zip(create_sample_gtfs_zip())

    rt_service = GTFSRealtimeService()
    # 2026-08-28 08:00:00 UTC (10:00:00 Stockholm CEST)
    # TRIP_18_0802 delayed by 3 minutes (180s), TRIP_17_0810 cancelled
    pb_data = create_sample_gtfs_rt_protobuf(
        feed_timestamp=1787990400,
        delay_seconds=180,
        cancelled_trip_id="TRIP_17_0810",
        delayed_trip_id="TRIP_18_0802",
    )
    rt_service.parse_feed(pb_data)

    service = DepartureService(db=db, rt_service=rt_service)
    return service


@pytest.mark.asyncio
async def test_get_departures_unfiltered(populated_departure_service):
    """Test retrieving upcoming departures with default parameters."""
    service = populated_departure_service
    # Query at 08:00 Stockholm time on 2026-08-28 (06:00 UTC)
    ref_time = datetime(2026, 8, 28, 6, 0, 0, tzinfo=timezone.utc)
    query = DeparturesQuery(
        stop_id="9021014001234000",
        time_window_minutes=15,
        limit=10,
    )

    response = await service.get_departures(query, reference_time=ref_time)
    assert response.stop_id == "9021014001234000"
    assert response.freshness_at is not None
    assert len(response.departures) >= 4

    # Trip 17_0800: 08:00 scheduled, on time / scheduled
    d0 = response.departures[0]
    assert d0.route == "17"
    assert d0.destination == "Åkeshov"
    assert d0.status == DepartureStatus.SCHEDULED
    assert d0.is_realtime is False

    # Trip 18_0802: 08:02 scheduled, delayed by 3 min (predicted 08:05)
    d1 = response.departures[1]
    assert d1.route == "18"
    assert d1.destination == "Alvik"
    assert d1.status == DepartureStatus.DELAYED
    assert d1.delay_minutes == 3
    assert d1.is_realtime is True
    assert d1.predicted_at is not None

    # Trip 43_0806: 08:06 scheduled
    d2 = response.departures[2]
    assert d2.route == "43"
    assert d2.destination == "Bålsta"

    # Trip 17_0810: 08:10 scheduled, cancelled
    d3 = response.departures[3]
    assert d3.route == "17"
    assert d3.destination == "Åkeshov"
    assert d3.status == DepartureStatus.CANCELLED
    assert d3.is_realtime is True


@pytest.mark.asyncio
async def test_get_departures_route_filter(populated_departure_service):
    """Test filtering departures by route_id."""
    service = populated_departure_service
    ref_time = datetime(2026, 8, 28, 6, 0, 0, tzinfo=timezone.utc)
    query = DeparturesQuery(
        stop_id="9021014001234000",
        route_id="43",
    )

    response = await service.get_departures(query, reference_time=ref_time)
    assert len(response.departures) > 0
    for dep in response.departures:
        assert dep.route == "43"
        assert dep.destination == "Bålsta"


@pytest.mark.asyncio
async def test_get_departures_destination_filter(populated_departure_service):
    """Test filtering departures by destination substring."""
    service = populated_departure_service
    ref_time = datetime(2026, 8, 28, 6, 0, 0, tzinfo=timezone.utc)
    query = DeparturesQuery(
        stop_id="9021014001234000",
        destination="Åkes",
    )

    response = await service.get_departures(query, reference_time=ref_time)
    assert len(response.departures) > 0
    for dep in response.departures:
        assert dep.destination == "Åkeshov"


@pytest.mark.asyncio
async def test_get_departures_limit(populated_departure_service):
    """Test applying limit to departure results."""
    service = populated_departure_service
    ref_time = datetime(2026, 8, 28, 6, 0, 0, tzinfo=timezone.utc)
    query = DeparturesQuery(
        stop_id="9021014001234000",
        limit=2,
    )

    response = await service.get_departures(query, reference_time=ref_time)
    assert len(response.departures) == 2


@pytest.mark.asyncio
async def test_get_departures_calendar_exception(populated_departure_service):
    """Test that calendar exception removal (e.g. 20261225) correctly removes weekday services."""
    service = populated_departure_service
    # 2026-12-25 is Friday, but calendar_dates has exception_type=2 for WEEKDAY
    xmas_date = datetime(2026, 12, 25, 6, 0, 0, tzinfo=timezone.utc)
    active_services = await service.get_active_service_ids(xmas_date.date())

    assert "WEEKDAY" not in active_services
    assert "HOLIDAY_SERVICE" in active_services
    assert "ALL_DAYS" in active_services
