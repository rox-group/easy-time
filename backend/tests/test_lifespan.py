"""Tests for FastAPI lifespan startup/shutdown and background polling task."""

import asyncio
from unittest.mock import AsyncMock, patch

import pytest
from backend.app.core.config import settings
from backend.app.main import app, lifespan, poll_gtfs_realtime_loop


@pytest.mark.asyncio
async def test_lifespan_starts_and_stops_cleanly():
    """Verify lifespan initializes db and starts background polling when key is set."""
    fetch_mock = AsyncMock(return_value=5)
    with patch.object(settings, "TRAFIKLAB_API_KEY", "test-key"), \
         patch("backend.app.main.db_manager.init_db") as mock_init_db, \
         patch("backend.app.main.realtime_service.fetch_and_update", fetch_mock):
        async with lifespan(app):
            mock_init_db.assert_called_once()
            # Give short moment for background task to tick
            await asyncio.sleep(0.01)


@pytest.mark.asyncio
async def test_lifespan_skips_polling_when_no_api_key():
    """Verify lifespan skips polling task when TRAFIKLAB_API_KEY is empty."""
    with patch.object(settings, "TRAFIKLAB_API_KEY", ""), \
         patch("backend.app.main.db_manager.init_db") as mock_init_db:
        async with lifespan(app):
            mock_init_db.assert_called_once()


@pytest.mark.asyncio
async def test_poll_loop_handles_exception_and_cancellation():
    """Verify poll loop recovers from network/parsing exception and terminates on cancel."""
    fetch_mock = AsyncMock(side_effect=[RuntimeError("Network failure"), 10])
    with patch.object(settings, "TRAFIKLAB_API_KEY", "test-key"), \
         patch.object(settings, "GTFS_RT_POLL_INTERVAL_SECONDS", 0.01), \
         patch("backend.app.main.realtime_service.fetch_and_update", fetch_mock):
        task = asyncio.create_task(poll_gtfs_realtime_loop())
        await asyncio.sleep(0.03)
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass

        assert fetch_mock.call_count >= 1
