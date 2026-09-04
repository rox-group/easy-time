"""GTFS-Realtime (TripUpdates) parsing, caching, and matching service."""

import logging
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Dict, Optional

import httpx
from backend.app.core.config import settings
from google.transit import gtfs_realtime_pb2

logger = logging.getLogger(__name__)


@dataclass
class RealtimeStopUpdate:
    """Realtime delay and departure predictions for a specific stop call."""

    stop_id: str
    stop_sequence: Optional[int] = None
    delay_seconds: Optional[int] = None
    predicted_time: Optional[datetime] = None
    schedule_relationship: str = "SCHEDULED"


@dataclass
class TripRealtimeData:
    """Realtime updates for a single trip."""

    trip_id: str
    route_id: Optional[str] = None
    schedule_relationship: str = "SCHEDULED"
    trip_delay_seconds: Optional[int] = None
    stop_updates: Dict[str, RealtimeStopUpdate] = field(default_factory=dict)


class GTFSRealtimeService:
    """Service to fetch, decode, and query GTFS-Realtime TripUpdates."""

    def __init__(self):
        self._trip_updates: Dict[str, TripRealtimeData] = {}
        self._freshness_at: Optional[datetime] = None
        self._last_polled_at: Optional[datetime] = None

    @property
    def freshness_at(self) -> Optional[datetime]:
        """Timestamp of the most recently ingested GTFS-RT feed."""
        return self._freshness_at

    def clear(self) -> None:
        """Clear all cached real-time predictions."""
        self._trip_updates.clear()
        self._freshness_at = None
        self._last_polled_at = None

    def parse_feed(self, pb_content: bytes) -> Dict[str, TripRealtimeData]:
        """Decode GTFS-RT Protobuf payload and extract trip updates."""
        feed = gtfs_realtime_pb2.FeedMessage()
        feed.ParseFromString(pb_content)

        if feed.header.HasField("timestamp"):
            feed_time = datetime.fromtimestamp(feed.header.timestamp, tz=timezone.utc)
        else:
            feed_time = datetime.now(timezone.utc)

        updates: Dict[str, TripRealtimeData] = {}

        for entity in feed.entity:
            if not entity.HasField("trip_update"):
                continue

            tu = entity.trip_update
            trip_id = tu.trip.trip_id
            if not trip_id:
                continue

            trip_rel = "SCHEDULED"
            if tu.trip.HasField("schedule_relationship"):
                trip_rel = gtfs_realtime_pb2.TripDescriptor.ScheduleRelationship.Name(
                    tu.trip.schedule_relationship
                )

            trip_delay = tu.delay if tu.HasField("delay") else None

            trip_data = TripRealtimeData(
                trip_id=trip_id,
                route_id=tu.trip.route_id if tu.trip.HasField("route_id") else None,
                schedule_relationship=trip_rel,
                trip_delay_seconds=trip_delay,
            )

            for stu in tu.stop_time_update:
                stop_id = stu.stop_id if stu.HasField("stop_id") else ""
                stop_seq = stu.stop_sequence if stu.HasField("stop_sequence") else None

                stu_rel = "SCHEDULED"
                if stu.HasField("schedule_relationship"):
                    stu_rel = (
                        gtfs_realtime_pb2.TripUpdate.StopTimeUpdate.ScheduleRelationship.Name(
                            stu.schedule_relationship
                        )
                    )

                delay_secs = None
                pred_dt = None

                # Prefer departure event over arrival event for departure predictions
                if stu.HasField("departure"):
                    dep = stu.departure
                    if dep.HasField("delay"):
                        delay_secs = dep.delay
                    if dep.HasField("time") and dep.time > 0:
                        pred_dt = datetime.fromtimestamp(dep.time, tz=timezone.utc)
                elif stu.HasField("arrival"):
                    arr = stu.arrival
                    if arr.HasField("delay"):
                        delay_secs = arr.delay
                    if arr.HasField("time") and arr.time > 0:
                        pred_dt = datetime.fromtimestamp(arr.time, tz=timezone.utc)

                if delay_secs is None and trip_delay is not None:
                    delay_secs = trip_delay

                if stop_id:
                    trip_data.stop_updates[stop_id] = RealtimeStopUpdate(
                        stop_id=stop_id,
                        stop_sequence=stop_seq,
                        delay_seconds=delay_secs,
                        predicted_time=pred_dt,
                        schedule_relationship=stu_rel,
                    )

            updates[trip_id] = trip_data

        self._trip_updates = updates
        self._freshness_at = feed_time
        self._last_polled_at = datetime.now(timezone.utc)
        logger.info(
            "Parsed GTFS-RT feed: %d trip updates, freshness_at=%s",
            len(updates),
            feed_time.isoformat(),
        )
        return updates

    async def fetch_and_update(
        self,
        api_key: Optional[str] = None,
        url: Optional[str] = None,
    ) -> int:
        """Fetch live GTFS-RT feed from Trafiklab and update cache."""
        target_url = url or settings.TRAFIKLAB_GTFS_RT_TRIP_UPDATES_URL
        key = api_key or settings.TRAFIKLAB_API_KEY
        params = {"key": key} if key else {}

        logger.info("Fetching GTFS-RT feed from %s", target_url)
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(target_url, params=params)
            response.raise_for_status()
            content = response.content

        updates = self.parse_feed(content)
        return len(updates)

    def get_trip_update(self, trip_id: str) -> Optional[TripRealtimeData]:
        """Get all real-time updates for a given trip ID."""
        return self._trip_updates.get(trip_id)

    def get_stop_update(self, trip_id: str, stop_id: str) -> Optional[RealtimeStopUpdate]:
        """Get real-time update for a specific trip and stop combination."""
        trip_data = self._trip_updates.get(trip_id)
        if not trip_data:
            return None
        return trip_data.stop_updates.get(stop_id)


# Global singleton instance for the application lifecycle
realtime_service = GTFSRealtimeService()
