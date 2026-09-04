"""GTFS static import service for parsing and storing timetable data."""

import csv
import io
import logging
import zipfile
from typing import BinaryIO, Dict, List, Optional, Tuple, Union

import httpx
from backend.app.core.config import settings
from backend.app.db.database import DatabaseManager, db_manager

logger = logging.getLogger(__name__)


def time_to_seconds(time_str: str) -> int:
    """Convert GTFS time string (HH:MM:SS or H:MM:SS, including >24h) to seconds from midnight."""
    parts = time_str.strip().split(":")
    if len(parts) != 3:
        raise ValueError(f"Invalid GTFS time format: '{time_str}'")
    hours, minutes, seconds = int(parts[0]), int(parts[1]), int(parts[2])
    return hours * 3600 + minutes * 60 + seconds


def seconds_to_time(secs: int) -> str:
    """Convert seconds from midnight back to HH:MM:SS string."""
    hours = secs // 3600
    remainder = secs % 3600
    minutes = remainder // 60
    seconds = remainder % 60
    return f"{hours:02d}:{minutes:02d}:{seconds:02d}"


class GTFSStaticImporter:
    """Service to parse and ingest GTFS static feeds into SQLite."""

    def __init__(self, db: Optional[DatabaseManager] = None):
        self.db = db or db_manager

    def import_from_zip(
        self,
        zip_source: Union[str, bytes, BinaryIO],
    ) -> Dict[str, int]:
        """Import GTFS data from a zip file or bytes archive."""
        self.db.init_db()
        counts: Dict[str, int] = {
            "stops": 0,
            "routes": 0,
            "trips": 0,
            "stop_times": 0,
            "calendar": 0,
            "calendar_dates": 0,
        }

        if isinstance(zip_source, bytes):
            zip_file = zipfile.ZipFile(io.BytesIO(zip_source))
        elif isinstance(zip_source, str):
            zip_file = zipfile.ZipFile(zip_source)
        else:
            zip_file = zipfile.ZipFile(zip_source)

        conn = self.db.get_sync_connection()
        try:
            with conn:
                # Temporarily disable foreign keys during bulk replacement
                conn.execute("PRAGMA foreign_keys = OFF;")

                # Clear old timetable data
                conn.execute("DELETE FROM stop_times;")
                conn.execute("DELETE FROM trips;")
                conn.execute("DELETE FROM routes;")
                conn.execute("DELETE FROM stops;")
                conn.execute("DELETE FROM calendar_dates;")
                conn.execute("DELETE FROM calendar;")

                # Import tables in logical dependency order
                if "stops.txt" in zip_file.namelist():
                    counts["stops"] = self._import_stops(zip_file.open("stops.txt"), conn)

                if "routes.txt" in zip_file.namelist():
                    counts["routes"] = self._import_routes(zip_file.open("routes.txt"), conn)

                if "calendar.txt" in zip_file.namelist():
                    counts["calendar"] = self._import_calendar(zip_file.open("calendar.txt"), conn)

                if "calendar_dates.txt" in zip_file.namelist():
                    counts["calendar_dates"] = self._import_calendar_dates(
                        zip_file.open("calendar_dates.txt"), conn
                    )

                if "trips.txt" in zip_file.namelist():
                    counts["trips"] = self._import_trips(zip_file.open("trips.txt"), conn)

                if "stop_times.txt" in zip_file.namelist():
                    counts["stop_times"] = self._import_stop_times(
                        zip_file.open("stop_times.txt"), conn
                    )

                conn.execute("PRAGMA foreign_keys = ON;")
                logger.info("Successfully imported GTFS static data: %s", counts)
                return counts
        finally:
            conn.close()

    def _get_reader(self, file_obj: BinaryIO) -> csv.DictReader:
        """Create a CSV DictReader with utf-8-sig decoding to handle BOM."""
        text_stream = io.TextIOWrapper(file_obj, encoding="utf-8-sig", newline="")
        return csv.DictReader(text_stream)

    def _import_stops(self, file_obj: BinaryIO, conn) -> int:
        reader = self._get_reader(file_obj)
        rows: List[Tuple] = []
        for r in reader:
            stop_id = r.get("stop_id", "").strip()
            if not stop_id:
                continue
            rows.append(
                (
                    stop_id,
                    r.get("stop_name", "").strip(),
                    r.get("platform_code", "").strip() or None,
                    r.get("parent_station", "").strip() or None,
                    float(r["stop_lat"]) if r.get("stop_lat") else None,
                    float(r["stop_lon"]) if r.get("stop_lon") else None,
                )
            )
        conn.executemany(
            """
            INSERT OR REPLACE INTO stops (
                stop_id, stop_name, platform_code, parent_station, stop_lat, stop_lon
            ) VALUES (?, ?, ?, ?, ?, ?)
            """,
            rows,
        )
        return len(rows)

    def _import_routes(self, file_obj: BinaryIO, conn) -> int:
        reader = self._get_reader(file_obj)
        rows: List[Tuple] = []
        for r in reader:
            route_id = r.get("route_id", "").strip()
            if not route_id:
                continue
            rows.append(
                (
                    route_id,
                    r.get("route_short_name", "").strip() or None,
                    r.get("route_long_name", "").strip() or None,
                    int(r["route_type"]) if r.get("route_type") else None,
                )
            )
        conn.executemany(
            """
            INSERT OR REPLACE INTO routes (route_id, route_short_name, route_long_name, route_type)
            VALUES (?, ?, ?, ?)
            """,
            rows,
        )
        return len(rows)

    def _import_calendar(self, file_obj: BinaryIO, conn) -> int:
        reader = self._get_reader(file_obj)
        rows: List[Tuple] = []
        for r in reader:
            service_id = r.get("service_id", "").strip()
            if not service_id:
                continue
            rows.append(
                (
                    service_id,
                    int(r.get("monday", 0)),
                    int(r.get("tuesday", 0)),
                    int(r.get("wednesday", 0)),
                    int(r.get("thursday", 0)),
                    int(r.get("friday", 0)),
                    int(r.get("saturday", 0)),
                    int(r.get("sunday", 0)),
                    r.get("start_date", "").strip(),
                    r.get("end_date", "").strip(),
                )
            )
        conn.executemany(
            """
            INSERT OR REPLACE INTO calendar (
                service_id, monday, tuesday, wednesday, thursday,
                friday, saturday, sunday, start_date, end_date
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            rows,
        )
        return len(rows)

    def _import_calendar_dates(self, file_obj: BinaryIO, conn) -> int:
        reader = self._get_reader(file_obj)
        rows: List[Tuple] = []
        for r in reader:
            service_id = r.get("service_id", "").strip()
            date_str = r.get("date", "").strip()
            if not service_id or not date_str:
                continue
            rows.append(
                (
                    service_id,
                    date_str,
                    int(r.get("exception_type", 1)),
                )
            )
        conn.executemany(
            """
            INSERT OR REPLACE INTO calendar_dates (service_id, date, exception_type)
            VALUES (?, ?, ?)
            """,
            rows,
        )
        return len(rows)

    def _import_trips(self, file_obj: BinaryIO, conn) -> int:
        reader = self._get_reader(file_obj)
        rows: List[Tuple] = []
        for r in reader:
            trip_id = r.get("trip_id", "").strip()
            route_id = r.get("route_id", "").strip()
            service_id = r.get("service_id", "").strip()
            if not trip_id or not route_id or not service_id:
                continue
            rows.append(
                (
                    trip_id,
                    route_id,
                    service_id,
                    r.get("trip_headsign", "").strip() or None,
                    r.get("direction_id", "").strip() or None,
                )
            )
        conn.executemany(
            """
            INSERT OR REPLACE INTO trips (
                trip_id, route_id, service_id, trip_headsign, direction_id
            ) VALUES (?, ?, ?, ?, ?)
            """,
            rows,
        )
        return len(rows)

    def _import_stop_times(self, file_obj: BinaryIO, conn, chunk_size: int = 5000) -> int:
        reader = self._get_reader(file_obj)
        total_rows = 0
        batch: List[Tuple] = []
        for r in reader:
            trip_id = r.get("trip_id", "").strip()
            stop_id = r.get("stop_id", "").strip()
            arr_str = r.get("arrival_time", "").strip()
            dep_str = r.get("departure_time", "").strip()
            seq_str = r.get("stop_sequence", "").strip()
            if not (trip_id and stop_id and arr_str and dep_str and seq_str):
                continue
            try:
                arr_secs = time_to_seconds(arr_str)
                dep_secs = time_to_seconds(dep_str)
                seq = int(seq_str)
            except ValueError:
                continue

            batch.append(
                (
                    trip_id,
                    stop_id,
                    seq,
                    arr_str,
                    dep_str,
                    arr_secs,
                    dep_secs,
                    int(r.get("pickup_type", 0) or 0),
                    int(r.get("drop_off_type", 0) or 0),
                )
            )

            if len(batch) >= chunk_size:
                conn.executemany(
                    """
                    INSERT OR REPLACE INTO stop_times (
                        trip_id, stop_id, stop_sequence, arrival_time, departure_time,
                        arrival_time_secs, departure_time_secs, pickup_type, drop_off_type
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    batch,
                )
                total_rows += len(batch)
                batch.clear()

        if batch:
            conn.executemany(
                """
                INSERT OR REPLACE INTO stop_times (
                    trip_id, stop_id, stop_sequence, arrival_time, departure_time,
                    arrival_time_secs, departure_time_secs, pickup_type, drop_off_type
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                batch,
            )
            total_rows += len(batch)

        return total_rows

    async def fetch_and_import(
        self,
        api_key: Optional[str] = None,
        url: Optional[str] = None,
    ) -> Dict[str, int]:
        """Download GTFS zip archive from Trafiklab and ingest it."""
        target_url = url or settings.TRAFIKLAB_GTFS_STATIC_URL
        key = api_key or settings.TRAFIKLAB_API_KEY
        params = {"key": key} if key else {}

        logger.info("Fetching GTFS static feed from %s", target_url)
        async with httpx.AsyncClient(timeout=120.0) as client:
            response = await client.get(target_url, params=params)
            response.raise_for_status()
            content = response.content

        return self.import_from_zip(content)
