"""Main FastAPI application entry point for Easy Time."""

from backend.app.api.v1.router import api_router
from backend.app.core.config import settings
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
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
