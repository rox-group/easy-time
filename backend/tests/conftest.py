"""Test fixtures and setup for Easy Time backend tests."""

import pytest
from backend.app.api.v1.departures import _get_departure_service
from backend.app.db.database import DatabaseManager
from backend.app.main import app
from backend.app.services.departure_service import DepartureService
from backend.app.services.gtfs_realtime import GTFSRealtimeService
from backend.app.services.gtfs_static import GTFSStaticImporter
from backend.tests.fixtures.gtfs_fixtures import (
    create_sample_gtfs_rt_protobuf,
    create_sample_gtfs_zip,
)
from fastapi.testclient import TestClient


@pytest.fixture
def test_departure_service(tmp_path) -> DepartureService:
    """Provide a departure service loaded with synthetic GTFS static and realtime data."""
    test_db_path = str(tmp_path / "test_api_gtfs.db")
    db = DatabaseManager(db_path=test_db_path)
    importer = GTFSStaticImporter(db=db)
    importer.import_from_zip(create_sample_gtfs_zip())

    rt_service = GTFSRealtimeService()
    pb_data = create_sample_gtfs_rt_protobuf(
        feed_timestamp=1787990400,
        delay_seconds=180,
    )
    rt_service.parse_feed(pb_data)

    return DepartureService(db=db, rt_service=rt_service)


@pytest.fixture
def client(test_departure_service: DepartureService) -> TestClient:
    """Provide a TestClient instance with dependency overrides for API tests."""
    app.dependency_overrides[_get_departure_service] = lambda: test_departure_service
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
