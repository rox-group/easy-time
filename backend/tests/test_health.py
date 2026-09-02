"""Tests for health check endpoints."""

from fastapi import status
from fastapi.testclient import TestClient


def test_root_healthz(client: TestClient):
    """Verify /healthz returns 200 OK with service details."""
    response = client.get("/healthz")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["status"] == "ok"
    assert "version" in data
    assert "service" in data


def test_v1_health(client: TestClient):
    """Verify /v1/health returns 200 OK with HealthResponse."""
    response = client.get("/v1/health")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["status"] == "ok"
    assert "version" in data
    assert "environment" in data
    assert "timestamp" in data
