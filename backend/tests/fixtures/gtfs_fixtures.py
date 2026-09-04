"""Synthetic GTFS static zip and GTFS-Realtime Protobuf fixtures for testing."""

import io
import zipfile

from google.transit import gtfs_realtime_pb2


def create_sample_gtfs_zip() -> bytes:
    """Create a deterministic synthetic in-memory GTFS static zip archive covering 24 hours."""
    buffer = io.BytesIO()

    stops_csv = """stop_id,stop_name,platform_code,parent_station,stop_lat,stop_lon
9021014001234000,Skanstull,2,,59.3075,18.0755
9021014001234001,Skanstull,3,,59.3075,18.0755
9021014001234002,T-Centralen,1,,59.3314,18.0617
9021014001234003,Åkeshov,1,,59.3421,17.9254
"""

    routes_csv = """route_id,route_short_name,route_long_name,route_type
17,17,Gröna linjen 17,1
18,18,Gröna linjen 18,1
43,43,Pendeltåg 43,2
"""

    calendar_csv = (
        "service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date\n"
        "WEEKDAY,1,1,1,1,1,0,0,20260101,20261231\n"
        "ALL_DAYS,1,1,1,1,1,1,1,20260101,20261231\n"
    )

    calendar_dates_csv = """service_id,date,exception_type
WEEKDAY,20261225,2
HOLIDAY_SERVICE,20261225,1
"""

    trips_lines = [
        "trip_id,route_id,service_id,trip_headsign,direction_id"
    ]
    stop_times_lines = [
        "trip_id,stop_id,stop_sequence,arrival_time,departure_time,pickup_type,drop_off_type"
    ]

    # Generate departures every 10 minutes for 24 hours
    for hour in range(24):
        for minute in (0, 10, 20, 30, 40, 50):
            # Route 17 outbound (platform 2)
            t17 = f"TRIP_17_{hour:02d}{minute:02d}"
            trips_lines.append(f"{t17},17,ALL_DAYS,Åkeshov,0")
            stop_times_lines.append(
                f"{t17},9021014001234000,1,{hour:02d}:{minute:02d}:00,{hour:02d}:{minute:02d}:00,0,0"
            )

            # Route 18 outbound (platform 2)
            t18 = f"TRIP_18_{hour:02d}{minute+2:02d}"
            trips_lines.append(f"{t18},18,ALL_DAYS,Alvik,0")
            stop_times_lines.append(
                f"{t18},9021014001234000,1,{hour:02d}:{(minute+2)%60:02d}:00,"
                f"{hour:02d}:{(minute+2)%60:02d}:00,0,0"
            )

            # Route 17 return (platform 3, stop 9021014001234001)
            t17_ret = f"TRIP_17_RET_{hour:02d}{minute+4:02d}"
            trips_lines.append(f"{t17_ret},17,ALL_DAYS,Skarpnäck,1")
            stop_times_lines.append(
                f"{t17_ret},9021014001234001,1,{hour:02d}:{(minute+4)%60:02d}:00,"
                f"{hour:02d}:{(minute+4)%60:02d}:00,0,0"
            )

            # Route 43 outbound (platform 2)
            t43 = f"TRIP_43_{hour:02d}{minute+6:02d}"
            trips_lines.append(f"{t43},43,ALL_DAYS,Bålsta,0")
            stop_times_lines.append(
                f"{t43},9021014001234000,1,{hour:02d}:{(minute+6)%60:02d}:00,"
                f"{hour:02d}:{(minute+6)%60:02d}:00,0,0"
            )

    trips_csv = "\n".join(trips_lines) + "\n"
    stop_times_csv = "\n".join(stop_times_lines) + "\n"

    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("stops.txt", stops_csv)
        zf.writestr("routes.txt", routes_csv)
        zf.writestr("calendar.txt", calendar_csv)
        zf.writestr("calendar_dates.txt", calendar_dates_csv)
        zf.writestr("trips.txt", trips_csv)
        zf.writestr("stop_times.txt", stop_times_csv)

    return buffer.getvalue()


def create_sample_gtfs_rt_protobuf(
    feed_timestamp: int = 1787990400,
    delay_seconds: int = 180,
    cancelled_trip_id: str = "TRIP_17_0810",
    delayed_trip_id: str = "TRIP_18_0802",
) -> bytes:
    """Create a synthetic GTFS-RT TripUpdates Protobuf payload."""
    feed = gtfs_realtime_pb2.FeedMessage()
    feed.header.gtfs_realtime_version = "2.0"
    feed.header.timestamp = feed_timestamp

    # Entity 1: Delayed trip with a delay at Skanstull
    if delayed_trip_id:
        entity1 = feed.entity.add()
        entity1.id = "update_1"
        tu1 = entity1.trip_update
        tu1.trip.trip_id = delayed_trip_id
        tu1.trip.route_id = "18"
        tu1.delay = delay_seconds

        stu1 = tu1.stop_time_update.add()
        stu1.stop_id = "9021014001234000"
        stu1.stop_sequence = 1
        stu1.departure.delay = delay_seconds

    # Entity 2: Cancelled trip
    if cancelled_trip_id:
        entity2 = feed.entity.add()
        entity2.id = "update_2"
        tu2 = entity2.trip_update
        tu2.trip.trip_id = cancelled_trip_id
        tu2.trip.schedule_relationship = (
            gtfs_realtime_pb2.TripDescriptor.ScheduleRelationship.CANCELED
        )

    return feed.SerializeToString()
