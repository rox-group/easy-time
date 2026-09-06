"""Service for querying and searching public transport stops in SQLite."""

import logging
from typing import List, Optional

from backend.app.db.database import DatabaseManager, db_manager
from backend.app.schemas.stops import StopItem, StopsResponse

logger = logging.getLogger(__name__)


class StopsService:
    """Service to search and list stops from the GTFS database."""

    def __init__(self, db: Optional[DatabaseManager] = None):
        self.db = db or db_manager

    async def search_stops(
        self, query: Optional[str] = None, limit: int = 20
    ) -> StopsResponse:
        """Search stops matching query string or return prominent stops."""
        limit = max(1, min(limit, 100))
        cleaned_query = query.strip() if query else None

        stops: List[StopItem] = []

        async with self.db.get_async_connection() as conn:
            if cleaned_query:
                sql = """
                    SELECT stop_id, stop_name, platform_code, parent_station, stop_lat, stop_lon
                    FROM stops
                    WHERE stop_name LIKE ? OR stop_id = ?
                    ORDER BY
                        CASE WHEN stop_name LIKE ? THEN 0 ELSE 1 END,
                        stop_name ASC
                    LIMIT ?
                """
                prefix_param = f"{cleaned_query}%"
                contains_param = f"%{cleaned_query}%"
                params = [contains_param, cleaned_query, prefix_param, limit]
            else:
                sql = """
                    SELECT stop_id, stop_name, platform_code, parent_station, stop_lat, stop_lon
                    FROM stops
                    ORDER BY stop_name ASC
                    LIMIT ?
                """
                params = [limit]

            async with conn.execute(sql, params) as cursor:
                rows = await cursor.fetchall()
                for row in rows:
                    stops.append(
                        StopItem(
                            stop_id=row["stop_id"],
                            stop_name=row["stop_name"],
                            platform_code=row["platform_code"],
                            parent_station=row["parent_station"],
                            stop_lat=row["stop_lat"],
                            stop_lon=row["stop_lon"],
                        )
                    )

        return StopsResponse(
            query=cleaned_query,
            count=len(stops),
            stops=stops,
        )


stops_service = StopsService()

