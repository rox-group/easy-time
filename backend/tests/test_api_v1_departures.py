"""Integration tests for GET /v1/departures endpoint."""

from fastapi import status
from fastapi.testclient import TestClient


def test_get_departures_success(client: TestClient):
    """Verify valid request returns 200 and well-formed DeparturesResponse."""
    response = client.get("/v1/departures", params={"stop_id": "9021014001234000"})
    assert response.status_code == status.HTTP_200_OK

    data = response.json()
    assert "generated_at" in data
    assert "freshness_at" in data
    assert data["stop_id"] == "9021014001234000"
    assert isinstance(data["departures"], list)
    assert len(data["departures"]) > 0

    first = data["departures"][0]
    assert "route" in first
    assert "destination" in first
    assert "scheduled_at" in first
    assert "status" in first
    assert "platform" in first


def test_get_departures_missing_stop_id(client: TestClient):
    """Verify missing required stop_id parameter returns 422 Unprocessable Entity."""
    response = client.get("/v1/departures")
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


def test_get_departures_empty_stop_id(client: TestClient):
    """Verify whitespace/empty stop_id returns 422."""
    response = client.get("/v1/departures", params={"stop_id": "   "})
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


def test_get_departures_filter_by_route(client: TestClient):
    """Verify filtering by route_id returns only matching routes."""
    response = client.get(
        "/v1/departures",
        params={"stop_id": "9021014001234000", "route_id": "17"},
    )
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    for dep in data["departures"]:
        assert dep["route"] == "17"


def test_get_departures_filter_by_direction(client: TestClient):
    """Verify filtering by direction returns appropriate outbound/return departures."""
    response = client.get(
        "/v1/departures",
        params={"stop_id": "9021014001234000", "direction": "0"},
    )
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert len(data["departures"]) > 0
    # direction 0 has platform 2 in sample pool
    for dep in data["departures"]:
        assert dep["platform"] == "2"


def test_get_departures_filter_by_destination(client: TestClient):
    """Verify filtering by destination headsign."""
    response = client.get(
        "/v1/departures",
        params={"stop_id": "9021014001234000", "destination": "Alvik"},
    )
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert len(data["departures"]) == 1
    assert data["departures"][0]["destination"] == "Alvik"


def test_get_departures_limit(client: TestClient):
    """Verify limit parameter restricts response array size."""
    response = client.get(
        "/v1/departures",
        params={"stop_id": "9021014001234000", "limit": 2},
    )
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert len(data["departures"]) <= 2


def test_get_departures_invalid_limit(client: TestClient):
    """Verify limit validation out of bounds."""
    response = client.get(
        "/v1/departures",
        params={"stop_id": "9021014001234000", "limit": 0},
    )
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY

    response = client.get(
        "/v1/departures",
        params={"stop_id": "9021014001234000", "limit": 100},
    )
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


def test_get_departures_filter_by_platform(client: TestClient):
    """Verify filtering by platform returns only departures on that platform."""
    response = client.get(
        "/v1/departures",
        params={"stop_id": "9021014001234000", "platform": "3"},
    )
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert len(data["departures"]) > 0
    for dep in data["departures"]:
        assert dep["platform"] == "3"


def test_get_departures_invalid_time_window(client: TestClient):
    """Verify time_window_minutes validation bounds."""
    response = client.get(
        "/v1/departures",
        params={"stop_id": "9021014001234000", "time_window_minutes": 2},
    )
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY

    response = client.get(
        "/v1/departures",
        params={"stop_id": "9021014001234000", "time_window_minutes": 500},
    )
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


def test_openapi_schema_endpoint(client: TestClient):
    """Verify OpenAPI JSON schema endpoint is reachable and well-formed."""
    response = client.get("/v1/openapi.json")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["info"]["title"] == "Easy Time API"
    assert "/v1/departures" in data["paths"]
    assert "/v1/health" in data["paths"]
