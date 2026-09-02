# Easy Time

Easy Time is an iPhone app for people in Stockholm who take the same public
transport journey every day. Instead of searching the full SL network each
time, a person saves an outbound and return commute and sees only the next
relevant departures.

## Product goal

Answer one question quickly: **when should I leave for my usual transport?**

Each saved commute contains two directions:

- **Outbound** — for example, Home → Work.
- **Return** — for example, Work → Home.

For each direction, the app filters departures by the selected stop, platform,
line, and destination. It will show real-time departure status, a configurable
walking buffer, and eventually a WidgetKit widget and departure reminder.

## Architecture

The app is iPhone-first and uses a small backend to keep the Trafiklab API key
out of the client and provide a fast, purpose-built departures API. See the
[architecture document](docs/architecture.md) for the system diagram and data
flow.

## Repository layout

```text
ios/                    Native SwiftUI iPhone app and tests
backend/                FastAPI service and backend tests
infrastructure/         Google Cloud infrastructure as code
docs/                   Product, architecture, and API documentation
.github/                CI, repository governance, and automation
```

## Planned technology

- Swift and SwiftUI for the iOS app.
- SwiftData for on-device saved commutes.
- Trafiklab GTFS Regional SL static and GTFS-Realtime feeds.
- FastAPI on Google Cloud Run for a small mobile API.
- PostgreSQL and a short-lived cache for transport data.
- Cloud Scheduler and Cloud Run Jobs for daily imports and real-time polling.
- WidgetKit and local notifications after the core departures screen is ready.

## Project status

| Step | Milestone | Status |
|------|-----------|--------|
| 1 | SwiftUI app shell — fixture-backed saved-commute screen | ✅ Done |
| 2 | Backend API contract and departure response model | ✅ Done |
| 3 | GTFS static import and GTFS-Realtime polling in the backend | ✅ Done |
| 4 | Connect iOS client to backend and add tests | 🔜 Next |
| 5 | WidgetKit and local departure reminders | ⬜ Pending |

**Current milestone (step 4):** wire the iOS client to the live backend API,
replace fixture data with real departures, and add integration tests.
## Contributing

Read [AGENTS.md](AGENTS.md) before making changes. Every pull request must pass
the configured CI checks before it is merged into `main`.
