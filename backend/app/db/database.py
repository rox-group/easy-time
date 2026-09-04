"""Database connection and schema management for Easy Time backend."""

import os
import sqlite3
from contextlib import asynccontextmanager
from typing import AsyncGenerator, Optional

import aiosqlite
from backend.app.core.config import settings

SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS stops (
    stop_id TEXT PRIMARY KEY,
    stop_name TEXT NOT NULL,
    platform_code TEXT,
    parent_station TEXT,
    stop_lat REAL,
    stop_lon REAL
);

CREATE TABLE IF NOT EXISTS routes (
    route_id TEXT PRIMARY KEY,
    route_short_name TEXT,
    route_long_name TEXT,
    route_type INTEGER
);

CREATE TABLE IF NOT EXISTS trips (
    trip_id TEXT PRIMARY KEY,
    route_id TEXT NOT NULL,
    service_id TEXT NOT NULL,
    trip_headsign TEXT,
    direction_id TEXT,
    FOREIGN KEY(route_id) REFERENCES routes(route_id)
);

CREATE TABLE IF NOT EXISTS stop_times (
    trip_id TEXT NOT NULL,
    stop_id TEXT NOT NULL,
    stop_sequence INTEGER NOT NULL,
    arrival_time TEXT NOT NULL,
    departure_time TEXT NOT NULL,
    arrival_time_secs INTEGER NOT NULL,
    departure_time_secs INTEGER NOT NULL,
    pickup_type INTEGER DEFAULT 0,
    drop_off_type INTEGER DEFAULT 0,
    PRIMARY KEY (trip_id, stop_sequence),
    FOREIGN KEY(trip_id) REFERENCES trips(trip_id),
    FOREIGN KEY(stop_id) REFERENCES stops(stop_id)
);

CREATE TABLE IF NOT EXISTS calendar (
    service_id TEXT PRIMARY KEY,
    monday INTEGER NOT NULL,
    tuesday INTEGER NOT NULL,
    wednesday INTEGER NOT NULL,
    thursday INTEGER NOT NULL,
    friday INTEGER NOT NULL,
    saturday INTEGER NOT NULL,
    sunday INTEGER NOT NULL,
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS calendar_dates (
    service_id TEXT NOT NULL,
    date TEXT NOT NULL,
    exception_type INTEGER NOT NULL,
    PRIMARY KEY (service_id, date)
);

CREATE INDEX IF NOT EXISTS idx_stop_times_stop_dep ON stop_times(stop_id, departure_time_secs);
CREATE INDEX IF NOT EXISTS idx_stop_times_trip ON stop_times(trip_id);
CREATE INDEX IF NOT EXISTS idx_trips_service ON trips(service_id);
CREATE INDEX IF NOT EXISTS idx_trips_route ON trips(route_id);
CREATE INDEX IF NOT EXISTS idx_calendar_dates_date ON calendar_dates(date);
"""


class DatabaseManager:
    """Manages SQLite database connections and schema initialization."""

    def __init__(self, db_path: Optional[str] = None):
        self.db_path = db_path or settings.GTFS_DB_PATH

    def _ensure_dir(self) -> None:
        """Ensure parent directory exists for file-based database."""
        if self.db_path != ":memory:":
            os.makedirs(os.path.dirname(os.path.abspath(self.db_path)), exist_ok=True)

    def init_db(self) -> None:
        """Initialize database schema synchronously."""
        self._ensure_dir()
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("PRAGMA journal_mode = WAL;")
            conn.execute("PRAGMA foreign_keys = ON;")
            conn.executescript(SCHEMA_SQL)
            conn.commit()

    def get_sync_connection(self) -> sqlite3.Connection:
        """Get a raw synchronous connection for bulk ingestion."""
        self._ensure_dir()
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON;")
        return conn

    @asynccontextmanager
    async def get_async_connection(self) -> AsyncGenerator[aiosqlite.Connection, None]:
        """Async context manager yielding an aiosqlite connection."""
        self._ensure_dir()
        async with aiosqlite.connect(self.db_path) as conn:
            conn.row_factory = aiosqlite.Row
            await conn.execute("PRAGMA foreign_keys = ON;")
            yield conn


db_manager = DatabaseManager()
