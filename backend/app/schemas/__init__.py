"""Pydantic schemas for Easy Time API."""

from backend.app.schemas.departure import (
    DepartureItem,
    DeparturesQuery,
    DeparturesResponse,
    DepartureStatus,
)
from backend.app.schemas.error import ErrorResponse
from backend.app.schemas.health import HealthResponse

__all__ = [
    "DepartureItem",
    "DeparturesQuery",
    "DeparturesResponse",
    "DepartureStatus",
    "ErrorResponse",
    "HealthResponse",
]
