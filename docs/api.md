# Easy Time API Contract

This document defines the REST API specification for Easy Time backend services.

## Overview

The Easy Time API is a lightweight, mobile-first HTTP service designed for Stockholm public-transport commuters. It serves saved-commute departures, abstracting and caching Trafiklab GTFS Regional static and GTFS-Realtime feeds.

- **Base Path**: `/v1`
- **Protocol**: HTTPS
- **Content Type**: `application/json`
- **Authentication**: Backend API key / rate limiting (managed via API Gateway / Cloud Run)

---

## Endpoints

### 1. Retrieve Departures

Retrieve upcoming departures for a specific boarding stop, filtered by route, direction, platform, and destination.

```http
GET /v1/departures
```

#### Query Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `stop_id` | `string` | **Yes** | — | GTFS stop or station identifier (e.g. `"9021014001234000"`). |
| `route_id` | `string` | No | `null` | Filter by route/line identifier (e.g. `"17"`, `"43"`). |
| `direction` | `string` | No | `null` | Filter by direction (`"0"`, `"1"`, `"outbound"`, `"return"`). |
| `platform` | `string` | No | `null` | Filter by track/platform designation (e.g. `"2"`). |
| `destination` | `string` | No | `null` | Filter by headsign / destination (case-insensitive substring). |
| `limit` | `integer` | No | `10` | Maximum number of departures to return (`1`–`50`). |
| `time_window_minutes` | `integer` | No | `60` | Future lookahead search window in minutes (`5`–`360`). |

#### Request Example

```http
GET /v1/departures?stop_id=9021014001234000&route_id=17&direction=0&platform=2&limit=5 HTTP/1.1
Host: api.easytime.app
Accept: application/json
```

#### Response (200 OK)

```json
{
  "generated_at": "2026-08-28T08:10:00Z",
  "freshness_at": "2026-08-28T08:09:45Z",
  "stop_id": "9021014001234000",
  "departures": [
    {
      "route": "17",
      "destination": "Åkeshov",
      "scheduled_at": "2026-08-28T08:18:00Z",
      "predicted_at": "2026-08-28T08:21:00Z",
      "platform": "2",
      "status": "delayed",
      "trip_id": "14010000637189101",
      "stop_id": "9021014001234000",
      "stop_name": "Skanstull",
      "delay_minutes": 3,
      "is_realtime": true
    },
    {
      "route": "17",
      "destination": "Åkeshov",
      "scheduled_at": "2026-08-28T08:28:00Z",
      "predicted_at": null,
      "platform": "2",
      "status": "scheduled",
      "trip_id": "14010000637189110",
      "stop_id": "9021014001234000",
      "stop_name": "Skanstull",
      "delay_minutes": null,
      "is_realtime": false
    }
  ]
}
```

#### Error Responses

- **`422 Unprocessable Entity`**: Missing or invalid query parameter (e.g. missing `stop_id` or out-of-range `limit`).

```json
{
  "detail": [
    {
      "loc": ["query", "stop_id"],
      "msg": "Field required",
      "type": "missing"
    }
  ]
}
```

---

### 2. Health Checks

#### Root Liveness Check

```http
GET /healthz
```

**Response (200 OK)**
```json
{
  "status": "ok",
  "service": "Easy Time API",
  "version": "0.1.0"
}
```

#### Service Health & Version

```http
GET /v1/health
```

**Response (200 OK)**
```json
{
  "status": "ok",
  "version": "0.1.0",
  "environment": "development",
  "timestamp": "2026-09-02T08:00:00Z"
}
```

---

## Data Models

### DepartureStatus Enum

| Value | Description |
|-------|-------------|
| `scheduled` | Departure based on static timetable without real-time prediction. |
| `on_time` | Real-time prediction matches scheduled time within threshold (0 min delay). |
| `delayed` | Real-time prediction is later than scheduled time. |
| `early` | Real-time prediction is earlier than scheduled time. |
| `cancelled` | Trip or stop call has been cancelled by the operator. |

### DepartureItem Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `route` | `string` | Yes | Line/Route number (e.g. `"17"`, `"43"`). |
| `destination` | `string` | Yes | Headsign / final destination name (e.g. `"Åkeshov"`). |
| `scheduled_at` | `string` (date-time) | Yes | Scheduled departure time in UTC (ISO 8601). |
| `predicted_at` | `string` (date-time) | No | Real-time estimated departure time in UTC (ISO 8601). |
| `platform` | `string` | No | Track / platform identifier (e.g. `"2"`). |
| `status` | `DepartureStatus` | Yes | Current operational status. |
| `trip_id` | `string` | No | GTFS trip identifier. |
| `stop_id` | `string` | No | GTFS stop identifier. |
| `stop_name` | `string` | No | Boarding stop name. |
| `delay_minutes` | `integer` | No | Delay in minutes (positive for delay, negative for early). |
| `is_realtime` | `boolean` | Yes | Flag indicating whether live real-time predictions are present. |

### DeparturesResponse Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `generated_at` | `string` (date-time) | Yes | Timestamp of response generation. |
| `freshness_at` | `string` (date-time) | No | Timestamp of the latest underlying GTFS-RT feed update. |
| `stop_id` | `string` | Yes | Requested boarding stop identifier. |
| `departures` | `array[DepartureItem]` | Yes | List of departures ordered by departure time. |
