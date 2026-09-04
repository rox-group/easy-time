"""Departure resolution service querying static schedule and merging realtime updates."""

import logging
from datetime import date, datetime, timedelta, timezone
from typing import List, Optional, Set
from zoneinfo import ZoneInfo

from backend.app.db.database import DatabaseManager, db_manager
from backend.app.schemas.departure import (
    DepartureItem,
    DeparturesQuery,
    DeparturesResponse,
    DepartureStatus,
)
from backend.app.services.gtfs_realtime import GTFSRealtimeService, realtime_service

logger = logging.getLogger(__name__)

STOCKHOLM_TZ = ZoneInfo("Europe/Stockholm")
WEEKDAY_COLS = [
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
    "sunday",
]


class DepartureService:
    """Service to resolve upcoming departures from static schedule and real-time feeds."""

    def __init__(
        self,
        db: Optional[DatabaseManager] = None,
        rt_service: Optional[GTFSRealtimeService] = None,
    ):
        self.db = db or db_manager
        self.rt_service = rt_service or realtime_service

    async def get_active_service_ids(self, target_date: date) -> Set[str]:
        """Find active service IDs for a given date considering calendar and calendar_dates."""
        date_str = target_date.strftime("%Y%m%d")
        weekday_col = WEEKDAY_COLS[target_date.weekday()]

        active_services: Set[str] = set()

        async with self.db.get_async_connection() as conn:
            # 1. Base calendar query for day of week within validity range
            calendar_query = f"""
                SELECT service_id FROM calendar
                WHERE {weekday_col} = 1
                  AND start_date <= ?
                  AND end_date >= ?
            """
            async with conn.execute(calendar_query, (date_str, date_str)) as cursor:
                rows = await cursor.fetchall()
                for row in rows:
                    active_services.add(row[0])

            # 2. Calendar exceptions (1 = Added, 2 = Removed)
            exceptions_query = """
                SELECT service_id, exception_type FROM calendar_dates
                WHERE date = ?
            """
            async with conn.execute(exceptions_query, (date_str,)) as cursor:
                rows = await cursor.fetchall()
                for row in rows:
                    service_id, exception_type = row[0], row[1]
                    if exception_type == 1:
                        active_services.add(service_id)
                    elif exception_type == 2:
                        active_services.discard(service_id)

        return active_services

    async def get_departures(
        self,
        query: DeparturesQuery,
        reference_time: Optional[datetime] = None,
    ) -> DeparturesResponse:
        """Resolve scheduled departures for the stop and overlay live real-time predictions."""
        now_utc = reference_time or datetime.now(timezone.utc)
        now_stockholm = now_utc.astimezone(STOCKHOLM_TZ)

        target_date = now_stockholm.date()
        date_midnight_stockholm = datetime(
            target_date.year, target_date.month, target_date.day, tzinfo=STOCKHOLM_TZ
        )

        current_secs = (
            now_stockholm.hour * 3600 + now_stockholm.minute * 60 + now_stockholm.second
        )
        max_secs = current_secs + (query.time_window_minutes * 60)

        # Retrieve active service IDs for today
        active_services = await self.get_active_service_ids(target_date)

        departures: List[DepartureItem] = []

        if not active_services:
            logger.debug("No active GTFS services found for date %s", target_date)
            return DeparturesResponse(
                generated_at=now_utc,
                freshness_at=self.rt_service.freshness_at,
                stop_id=query.stop_id,
                departures=[],
            )

        placeholders = ",".join("?" for _ in active_services)
        sql = f"""
            SELECT
                st.trip_id,
                st.stop_id,
                st.stop_sequence,
                st.departure_time_secs,
                t.route_id,
                t.trip_headsign,
                t.direction_id,
                r.route_short_name,
                r.route_long_name,
                s.stop_name,
                s.platform_code
            FROM stop_times st
            JOIN trips t ON st.trip_id = t.trip_id
            JOIN routes r ON t.route_id = r.route_id
            JOIN stops s ON st.stop_id = s.stop_id
            WHERE (st.stop_id = ? OR s.parent_station = ?)
              AND t.service_id IN ({placeholders})
              AND st.departure_time_secs >= ?
              AND st.departure_time_secs <= ?
            ORDER BY st.departure_time_secs ASC
        """

        params = [query.stop_id, query.stop_id, *active_services, current_secs, max_secs]

        async with self.db.get_async_connection() as conn:
            async with conn.execute(sql, params) as cursor:
                rows = await cursor.fetchall()

        for row in rows:
            trip_id = row["trip_id"]
            stop_id = row["stop_id"]
            dep_secs = row["departure_time_secs"]
            route_id = row["route_id"]
            trip_headsign = row["trip_headsign"] or ""
            direction_id = row["direction_id"] or ""
            route_short_name = row["route_short_name"] or route_id
            stop_name = row["stop_name"]
            platform_code = row["platform_code"]

            # --- Apply Filters ---
            # 1. Route filter
            if query.route_id and query.route_id not in (route_id, route_short_name):
                continue

            # 2. Platform filter
            if query.platform and platform_code != query.platform:
                continue

            # 3. Destination filter (case-insensitive substring)
            if query.destination and query.destination.lower() not in trip_headsign.lower():
                continue

            # 4. Direction filter
            if query.direction:
                norm_dir = query.direction.lower()
                if norm_dir in ("0", "outbound") and direction_id not in ("0", ""):
                    continue
                if norm_dir in ("1", "return") and direction_id != "1":
                    continue

            # Compute scheduled departure time in UTC
            scheduled_dt_stockholm = date_midnight_stockholm + timedelta(seconds=dep_secs)
            scheduled_at_utc = scheduled_dt_stockholm.astimezone(timezone.utc)

            # Check realtime overlay
            trip_rt = self.rt_service.get_trip_update(trip_id)
            stop_rt = self.rt_service.get_stop_update(trip_id, stop_id)

            is_realtime = False
            predicted_at_utc = None
            delay_minutes = None
            status = DepartureStatus.SCHEDULED

            if trip_rt and trip_rt.schedule_relationship == "CANCELED":
                status = DepartureStatus.CANCELLED
                is_realtime = True
            elif stop_rt and stop_rt.schedule_relationship == "SKIPPED":
                status = DepartureStatus.CANCELLED
                is_realtime = True
            elif stop_rt and (
                stop_rt.predicted_time or stop_rt.delay_seconds is not None
            ):
                is_realtime = True
                if stop_rt.predicted_time:
                    predicted_at_utc = stop_rt.predicted_time
                    delay_seconds = (
                        predicted_at_utc - scheduled_at_utc
                    ).total_seconds()
                    delay_minutes = int(round(delay_seconds / 60))
                elif stop_rt.delay_seconds is not None:
                    delay_minutes = int(round(stop_rt.delay_seconds / 60))
                    predicted_at_utc = scheduled_at_utc + timedelta(
                        seconds=stop_rt.delay_seconds
                    )

                if delay_minutes > 0:
                    status = DepartureStatus.DELAYED
                elif delay_minutes < 0:
                    status = DepartureStatus.EARLY
                else:
                    status = DepartureStatus.ON_TIME
            elif trip_rt and trip_rt.trip_delay_seconds is not None:
                is_realtime = True
                delay_minutes = int(round(trip_rt.trip_delay_seconds / 60))
                predicted_at_utc = scheduled_at_utc + timedelta(
                    seconds=trip_rt.trip_delay_seconds
                )
                if delay_minutes > 0:
                    status = DepartureStatus.DELAYED
                elif delay_minutes < 0:
                    status = DepartureStatus.EARLY
                else:
                    status = DepartureStatus.ON_TIME

            departure_item = DepartureItem(
                route=route_short_name,
                destination=trip_headsign,
                scheduled_at=scheduled_at_utc,
                predicted_at=predicted_at_utc,
                platform=platform_code,
                status=status,
                trip_id=trip_id,
                stop_id=stop_id,
                stop_name=stop_name,
                delay_minutes=delay_minutes,
                is_realtime=is_realtime,
            )
            departures.append(departure_item)

            if len(departures) >= query.limit:
                break

        return DeparturesResponse(
            generated_at=now_utc,
            freshness_at=self.rt_service.freshness_at,
            stop_id=query.stop_id,
            departures=departures,
        )


departure_service = DepartureService()
