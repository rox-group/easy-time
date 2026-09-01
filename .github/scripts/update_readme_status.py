#!/usr/bin/env python3
"""Auto-sync README.md project status table based on milestone completion signals.

Each milestone is considered complete when its key indicator file or directory exists.
Run this script from the repository root or via the readme-sync GitHub Actions workflow.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent


# ---------------------------------------------------------------------------
# Milestone definitions
# Each entry: (display_label, done_check_fn, step_description)
# ---------------------------------------------------------------------------

MILESTONES = [
    (
        "SwiftUI app shell — fixture-backed saved-commute screen",
        lambda: (ROOT / "ios/EasyTime/Views/ContentView.swift").exists()
        and (ROOT / "ios/EasyTime/Views/ContentView.swift").stat().st_size > 500,
        "add WidgetKit and local departure reminder notifications.",
    ),
    (
        "Backend API contract and departure response model",
        lambda: (ROOT / "backend/app/main.py").exists()
        and (ROOT / "backend/app/main.py").stat().st_size > 100,
        "define the FastAPI endpoint contract\n(`GET /v1/departures`), the JSON response schema, and the backend departure\n"
        "model. See [`docs/architecture.md`](docs/architecture.md) for the proposed\nAPI shape.",
    ),
    (
        "GTFS static import and GTFS-Realtime polling in the backend",
        lambda: any(
            (ROOT / "backend/app").rglob(pattern)
            for pattern in ("*gtfs*", "*ingest*", "*import*")
        ),
        "implement the daily GTFS static import job and\nthe GTFS-Realtime polling job. See [`docs/architecture.md`](docs/architecture.md)\n"
        "for the data ingestion design.",
    ),
    (
        "Connect iOS client to backend and add tests",
        lambda: (ROOT / "ios/EasyTime/Networking").exists()
        or (ROOT / "ios/EasyTime/Services").exists(),
        "wire the iOS client to the live backend API,\nreplace fixture data with real departures, and add integration tests.",
    ),
    (
        "WidgetKit and local departure reminders",
        lambda: (ROOT / "ios/EasyTimeWidget").exists(),
        "add a WidgetKit extension for glanceable\ndeparture times and set up local departure reminder notifications.",
    ),
]


def compute_statuses():
    results = []
    for label, check, desc in MILESTONES:
        try:
            done = check()
        except Exception:
            done = False
        results.append((label, done, desc))
    return results


def build_table(statuses):
    rows = []
    next_found = False
    for i, (label, done, _) in enumerate(statuses, 1):
        if done:
            icon = "✅ Done"
        elif not next_found:
            icon = "🔜 Next"
            next_found = True
        else:
            icon = "⬜ Pending"
        rows.append(f"| {i} | {label} | {icon} |")
    header = "| Step | Milestone | Status |\n|------|-----------|--------|"
    return f"{header}\n" + "\n".join(rows)


def build_current_milestone_note(statuses):
    for i, (_, done, desc) in enumerate(statuses, 1):
        if not done:
            return f"**Current milestone (step {i}):** {desc}"
    return "**All milestones complete!** 🎉"


def update_readme(table: str, note: str) -> bool:
    readme_path = ROOT / "README.md"
    original = readme_path.read_text(encoding="utf-8")

    new_block = f"## Project status\n\n{table}\n\n{note}"
    pattern = r"## Project status\n.*?(?=\n## |\Z)"
    updated = re.sub(pattern, new_block, original, flags=re.DOTALL)

    if updated == original:
        return False

    readme_path.write_text(updated, encoding="utf-8")
    return True


if __name__ == "__main__":
    statuses = compute_statuses()
    table = build_table(statuses)
    note = build_current_milestone_note(statuses)
    changed = update_readme(table, note)
    if changed:
        print("README.md milestone table updated.")
    else:
        print("README.md already up to date.")
    sys.exit(0)
