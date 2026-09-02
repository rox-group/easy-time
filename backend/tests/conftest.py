"""Test fixtures and setup for Easy Time backend tests."""

import pytest
from backend.app.main import app
from fastapi.testclient import TestClient


@pytest.fixture
def client() -> TestClient:
    """Provide a TestClient instance for API tests."""
    return TestClient(app)
