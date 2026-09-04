"""Unit tests for GTFS static data import and time utilities."""

import pytest
from backend.app.db.database import DatabaseManager
from backend.app.services.gtfs_static import (
    GTFSStaticImporter,
    seconds_to_time,
    time_to_seconds,
)
from backend.tests.fixtures.gtfs_fixtures import create_sample_gtfs_zip


def test_time_conversions():
    """Verify GTFS time string to seconds and round-trip conversion."""
    assert time_to_seconds("00:00:00") == 0
    assert time_to_seconds("08:15:30") == 8 * 3600 + 15 * 60 + 30
    assert time_to_seconds("24:00:00") == 86400
    assert time_to_seconds("25:30:00") == 25 * 3600 + 30 * 60

    assert seconds_to_time(0) == "00:00:00"
    assert seconds_to_time(29730) == "08:15:30"
    assert seconds_to_time(91800) == "25:30:00"

    with pytest.raises(ValueError):
        time_to_seconds("invalid_time")


def test_gtfs_static_import(tmp_path):
    """Verify importing a GTFS static zip archive into SQLite database."""
    test_db_path = str(tmp_path / "test_gtfs.db")
    db = DatabaseManager(db_path=test_db_path)
    importer = GTFSStaticImporter(db=db)

    zip_bytes = create_sample_gtfs_zip()
    counts = importer.import_from_zip(zip_bytes)

    assert counts["stops"] == 4
    assert counts["routes"] == 3
    assert counts["calendar"] == 2
    assert counts["calendar_dates"] == 2
    assert counts["trips"] == 576
    assert counts["stop_times"] == 576

    conn = db.get_sync_connection()
    try:
        # Check stops table
        stops = conn.execute(
            "SELECT stop_id, stop_name, platform_code FROM stops ORDER BY stop_id"
        ).fetchall()
        assert len(stops) == 4
        assert stops[0]["stop_id"] == "9021014001234000"
        assert stops[0]["stop_name"] == "Skanstull"
        assert stops[0]["platform_code"] == "2"

        # Check routes table
        routes = conn.execute(
            "SELECT route_id, route_short_name FROM routes ORDER BY route_id"
        ).fetchall()
        assert len(routes) == 3

        # Check stop_times departure seconds conversion
        query = (
            "SELECT trip_id, stop_id, departure_time, departure_time_secs "
            "FROM stop_times WHERE trip_id = 'TRIP_17_0800' AND stop_sequence = 1"
        )
        st = conn.execute(query).fetchone()
        assert st["departure_time"] == "08:00:00"
        assert st["departure_time_secs"] == 8 * 3600
    finally:
        conn.close()
