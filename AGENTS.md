# Easy Time agent guide

## Product context

Easy Time is an iPhone app for saved Stockholm public-transport commutes. It
should show only the departures relevant to a person's outbound and return
journeys, rather than providing a general journey-planning experience.

## Architecture decisions

- Build the client as a native SwiftUI iPhone app.
- Use Trafiklab's SL GTFS Regional static and GTFS-Realtime feeds as the
  transport-data source.
- Put data ingestion, feed parsing, caching, and API-key handling in the
  backend; never ship a Trafiklab key in the iOS app.
- Store saved commute preferences on the device first. Add sign-in and sync
  only when they solve a confirmed user need.
- Keep the public backend API focused on saved-commute departures, not a
  general route-search API.

## Product boundaries for version 1

- Include saved outbound and return directions, next departures, delays, and a
  walking-time buffer.
- Exclude ticket purchase, full journey planning, continuous location tracking,
  and social features.
- Location is optional. Manual stop selection must always work without location
  permission.

## Working rules

- Read the nearest `AGENTS.md` and relevant README before changing a component.
- Keep iOS, backend, infrastructure, and documentation changes in their
  respective top-level directories.
- Do not add secrets, API keys, provisioning profiles, or production data to
  Git. Use environment variables and secret managers.
- Add or update tests with behavior changes. Keep the architecture document and
  API contract current when data flows or public endpoints change.
- Preserve the merge safeguards configured in `.github/`; do not weaken CI to
  make a pull request pass.

## First implementation sequence

1. Create the SwiftUI app shell and a fixture-backed saved-commute screen.
2. Define the backend API contract and departure response model.
3. Implement GTFS static import and GTFS-Realtime polling in the backend.
4. Connect the iOS client to the backend and add tests.
5. Add WidgetKit and local departure reminders.
