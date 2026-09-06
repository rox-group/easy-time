import asyncio
import logging
from contextlib import asynccontextmanager

from backend.app.api.v1.router import api_router
from backend.app.core.config import settings
from backend.app.db.database import db_manager
from backend.app.services.gtfs_realtime import realtime_service
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

logger = logging.getLogger(__name__)


async def poll_gtfs_realtime_loop() -> None:
    """Background polling loop for GTFS-Realtime trip updates."""
    logger.info("Starting GTFS-Realtime background polling worker...")
    while True:
        try:
            if settings.TRAFIKLAB_API_KEY:
                await realtime_service.fetch_and_update()
            else:
                logger.debug("GTFS-Realtime polling skipped: TRAFIKLAB_API_KEY is not configured.")
        except asyncio.CancelledError:
            logger.info("GTFS-Realtime polling worker cancelled.")
            break
        except Exception as exc:
            logger.warning("Error during GTFS-Realtime polling: %s", exc)

        try:
            await asyncio.sleep(settings.GTFS_RT_POLL_INTERVAL_SECONDS)
        except asyncio.CancelledError:
            break


@asynccontextmanager
async def lifespan(app: FastAPI):
    """FastAPI lifespan context manager handling startup and shutdown tasks."""
    logger.info("Initializing Easy Time database schema...")
    db_manager.init_db()

    poll_task = None
    if settings.TRAFIKLAB_API_KEY:
        poll_task = asyncio.create_task(poll_gtfs_realtime_loop())

    yield

    if poll_task and not poll_task.done():
        poll_task.cancel()
        try:
            await poll_task
        except asyncio.CancelledError:
            pass


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    lifespan=lifespan,
    description=(
        "Easy Time API provides departure times and real-time status for Stockholm saved commutes "
        "using Trafiklab GTFS Regional static and GTFS-Realtime feeds."
    ),
    openapi_url=f"{settings.API_V1_STR}{settings.OPENAPI_URL}",
    docs_url=f"{settings.API_V1_STR}{settings.DOCS_URL}",
    redoc_url=f"{settings.API_V1_STR}/redoc",
    openapi_tags=[
        {
            "name": "Departures",
            "description": "Endpoints for retrieving scheduled and real-time commute departures.",
        },
        {
            "name": "Health",
            "description": "Service health check and monitoring endpoints.",
        },
    ],
)

# Set all CORS enabled origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Root health check alias
@app.get(
    "/healthz",
    tags=["Health"],
    summary="Liveness check",
    description="Root liveness check for Cloud Run and load balancers.",
)
async def healthz() -> JSONResponse:
    """Root health check for infrastructure monitors."""
    return JSONResponse(
        content={
            "status": "ok",
            "service": settings.PROJECT_NAME,
            "version": settings.VERSION,
        }
    )


# Include API v1 router
app.include_router(api_router, prefix=settings.API_V1_STR)
