"""API v1 router aggregator."""

from backend.app.api.v1 import departures, health
from fastapi import APIRouter

api_router = APIRouter()
api_router.include_router(health.router, tags=["Health"])
api_router.include_router(departures.router, tags=["Departures"])
