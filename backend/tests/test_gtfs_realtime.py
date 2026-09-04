"""Unit tests for GTFS-Realtime Protobuf parsing and caching."""

from datetime import datetime, timezone

from backend.app.services.gtfs_realtime import GTFSRealtimeService
from backend.tests.fixtures.gtfs_fixtures import create_sample_gtfs_rt_protobuf


def test_gtfs_realtime_parse_and_query():
    """Verify parsing GTFS-RT TripUpdates protobuf feed and querying stop updates."""
    rt_service = GTFSRealtimeService()
    feed_timestamp = 1787990400  # 2026-08-28 08:00:00 UTC
    pb_data = create_sample_gtfs_rt_protobuf(
        feed_timestamp=feed_timestamp,
        delay_seconds=180,
    )

    updates = rt_service.parse_feed(pb_data)
    assert len(updates) == 2
    assert rt_service.freshness_at == datetime.fromtimestamp(feed_timestamp, tz=timezone.utc)

    # Check delayed trip
    trip_18 = rt_service.get_trip_update("TRIP_18_0802")
    assert trip_18 is not None
    assert trip_18.route_id == "18"
    assert trip_18.trip_delay_seconds == 180

    stop_update = rt_service.get_stop_update("TRIP_18_0802", "9021014001234000")
    assert stop_update is not None
    assert stop_update.delay_seconds == 180
    assert stop_update.schedule_relationship == "SCHEDULED"

    # Check cancelled trip
    trip_17_cancel = rt_service.get_trip_update("TRIP_17_0810")
    assert trip_17_cancel is not None
    assert trip_17_cancel.schedule_relationship == "CANCELED"

    # Check clear cache
    rt_service.clear()
    assert len(rt_service._trip_updates) == 0
    assert rt_service.freshness_at is None
    assert rt_service.get_trip_update("TRIP_18_0802") is None
