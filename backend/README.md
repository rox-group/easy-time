# Easy Time Backend

FastAPI backend service for Easy Time, providing scheduled and real-time departure endpoints for saved Stockholm public-transport commutes.

## Key Features

- **Purpose-Built API**: Provides lightweight, targeted departure feeds (`GET /v1/departures`) filtered by stop, route, direction, platform, and destination.
- **Provider Insulation**: Insulates the iOS client from Trafiklab GTFS Regional static files and GTFS-Realtime Protobuf feeds.
- **Privacy & Security**: Keeps Trafiklab API credentials securely in the backend, never on device.
- **Standardized Departure Model**: Normalizes scheduled departure times, real-time predictions, delays, and statuses (`on_time`, `delayed`, `early`, `cancelled`, `scheduled`).

## Project Layout

```text
backend/
├── app/
│   ├── api/
│   │   └── v1/
│   │       ├── departures.py   # GET /v1/departures endpoint
│   │       ├── health.py       # GET /v1/health endpoint
│   │       └── router.py       # API v1 router aggregator
│   ├── core/
│   │   └── config.py           # Application settings and environment config
│   ├── schemas/
│   │   ├── departure.py        # Pydantic models for departures and query params
│   │   ├── error.py            # Error response models
│   │   └── health.py           # Health response model
│   └── main.py                 # FastAPI application instance & middleware
├── tests/
│   ├── conftest.py             # Pytest fixtures and TestClient setup
│   ├── test_api_v1_departures.py # Integration tests for departures endpoint
│   ├── test_health.py          # Health check endpoint tests
│   └── test_schemas.py         # Pydantic schema validation tests
├── pyproject.toml              # Project metadata and tool configuration
├── requirements.txt            # Runtime dependencies
└── requirements-dev.txt        # Development and testing dependencies
```

## Local Setup & Development

### 1. Create and activate a virtual environment

```bash
python3 -m venv .venv
source .venv/bin/activate
```

### 2. Install dependencies

```bash
pip install -r requirements-dev.txt
```

### 3. Run the development server

```bash
uvicorn backend.app.main:app --reload --port 8000
```

Interactive documentation is available at:

- **Swagger UI**: [http://localhost:8000/v1/docs](http://localhost:8000/v1/docs)
- **ReDoc**: [http://localhost:8000/v1/redoc](http://localhost:8000/v1/redoc)
- **OpenAPI JSON**: [http://localhost:8000/v1/openapi.json](http://localhost:8000/v1/openapi.json)

### 4. Run tests

```bash
pytest backend/tests -v
```
