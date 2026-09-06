"""Integration and unit tests for the /v1/stops endpoint and StopsService."""

from fastapi.testclient import TestClient


def test_search_stops_unfiltered(client: TestClient):
    response = client.get("/v1/stops")
    assert response.status_code == 200
    data = response.json()
    assert data["count"] >= 4
    assert len(data["stops"]) >= 4
    stop_names = [s["stop_name"] for s in data["stops"]]
    assert "Skanstull" in stop_names
    assert "T-Centralen" in stop_names


def test_search_stops_with_query(client: TestClient):
    response = client.get("/v1/stops?query=Centralen")
    assert response.status_code == 200
    data = response.json()
    assert data["query"] == "Centralen"
    assert data["count"] == 1
    assert data["stops"][0]["stop_name"] == "T-Centralen"
    assert data["stops"][0]["stop_id"] == "9021014001234002"


def test_search_stops_limit(client: TestClient):
    response = client.get("/v1/stops?limit=2")
    assert response.status_code == 200
    data = response.json()
    assert data["count"] == 2
    assert len(data["stops"]) == 2


def test_search_stops_no_match(client: TestClient):
    response = client.get("/v1/stops?query=NonExistentStation")
    assert response.status_code == 200
    data = response.json()
    assert data["count"] == 0
    assert data["stops"] == []

