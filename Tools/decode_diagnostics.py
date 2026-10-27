#!/usr/bin/env python3
"""Decode a Formation Flight diagnostic JSON report using only Python's stdlib."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable


def load_report(path: Path) -> dict[str, Any]:
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"Could not read diagnostic JSON: {error}") from error

    required = {"schemaVersion", "sessionID", "startedAt", "flight", "events"}
    missing = sorted(required - report.keys())
    if missing:
        raise ValueError(f"Not a Formation Flight diagnostic report; missing: {', '.join(missing)}")
    if report["schemaVersion"] != 1:
        raise ValueError(f"Unsupported diagnostic schema version: {report['schemaVersion']}")
    if not isinstance(report["events"], list):
        raise ValueError("The events field must be an array")
    return report


def write_csv(path: Path, rows: Iterable[dict[str, Any]], fields: list[str]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def event_rows(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        {
            "sequence": event.get("sequence"),
            "timestamp": event.get("timestamp"),
            "kind": event.get("kind"),
            "detail": event.get("detail"),
            "status": event.get("status"),
            "isFixStale": event.get("isFixStale"),
        }
        for event in events
    ]


def location_rows(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    fields = [
        "sequence", "timestamp", "fixTimestamp", "fixAgeSeconds", "latitude",
        "longitude", "altitudeMeters", "horizontalAccuracyMeters",
        "verticalAccuracyMeters", "speedMetersPerSecond",
        "speedAccuracyMetersPerSecond", "courseDegreesTrue",
        "courseAccuracyDegrees",
    ]
    return [{field: event.get(field) for field in fields} for event in events if event.get("kind") == "location"]


def calculation_rows(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    fields = [
        "sequence", "timestamp", "tot", "distanceMeters", "bearingDegreesTrue",
        "trackDegreesTrue", "eteSeconds", "eta", "deltaSeconds",
        "requiredGroundSpeedMetersPerSecond", "status", "isFixStale",
        "turnDirection", "turnInDirection", "turnDurationSeconds",
    ]
    return [{field: event.get(field) for field in fields} for event in events if event.get("kind") == "calculation"]


def warnings_for(report: dict[str, Any]) -> list[str]:
    warnings: list[str] = []
    locations = [event for event in report["events"] if event.get("kind") == "location"]
    calculations = [event for event in report["events"] if event.get("kind") == "calculation"]

    if not locations:
        warnings.append("No GPS fixes were recorded.")
    stale_count = sum(bool(event.get("isFixStale")) for event in calculations)
    if stale_count:
        warnings.append(f"{stale_count} calculation samples used a stale or missing GPS fix.")
    inaccurate = [
        event for event in locations
        if isinstance(event.get("horizontalAccuracyMeters"), (int, float))
        and event["horizontalAccuracyMeters"] > 100
    ]
    if inaccurate:
        warnings.append(f"{len(inaccurate)} GPS fixes had horizontal accuracy worse than 100 m.")
    ages = [
        event.get("fixAgeSeconds") for event in locations
        if isinstance(event.get("fixAgeSeconds"), (int, float))
    ]
    if ages and max(ages) > 15:
        warnings.append(f"Oldest delivered GPS fix was {max(ages):.1f} seconds old.")

    sequences = [event.get("sequence") for event in report["events"]]
    if sequences != list(range(len(sequences))):
        warnings.append("Event sequence numbers contain a gap or are out of order.")
    return warnings


def make_report_text(report: dict[str, Any], warnings: list[str]) -> str:
    flight = report["flight"]
    events = report["events"]
    counts: dict[str, int] = {}
    for event in events:
        kind = str(event.get("kind", "unknown"))
        counts[kind] = counts.get(kind, 0) + 1

    duration = report.get("durationSeconds")
    duration_text = f"{duration:.1f} seconds" if isinstance(duration, (int, float)) else "unknown"
    lines = [
        "Formation Flight Diagnostic Report",
        f"Session: {report['sessionID']}",
        f"Flight: {flight.get('missionName', 'Unknown')}",
        f"Started: {report.get('startedAt', 'Unknown')}",
        f"Ended: {report.get('endedAt', 'Unknown')}",
        f"Duration: {duration_text}",
        f"App: {report.get('appVersion', 'unknown')} ({report.get('appBuild', 'unknown')})",
        f"OS: {report.get('operatingSystem', 'unknown')}",
        f"Device: {report.get('deviceModel', 'unknown')}",
        "",
        "Event counts:",
    ]
    lines.extend(f"  {kind}: {count}" for kind, count in sorted(counts.items()))
    lines.append("")
    lines.append("Warnings:")
    lines.extend(f"  - {warning}" for warning in warnings)
    if not warnings:
        lines.append("  None detected by the basic decoder checks.")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("diagnostic_json", type=Path)
    parser.add_argument(
        "--output",
        type=Path,
        help="Output directory (default: a folder beside the JSON file)",
    )
    args = parser.parse_args()

    try:
        report = load_report(args.diagnostic_json)
    except ValueError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    output = args.output or args.diagnostic_json.with_name(f"{args.diagnostic_json.stem}_decoded")
    output.mkdir(parents=True, exist_ok=True)
    events = report["events"]
    warnings = warnings_for(report)

    write_csv(
        output / "timeline.csv",
        event_rows(events),
        ["sequence", "timestamp", "kind", "detail", "status", "isFixStale"],
    )
    locations = location_rows(events)
    write_csv(
        output / "locations.csv",
        locations,
        list(locations[0].keys()) if locations else [
            "sequence", "timestamp", "fixTimestamp", "fixAgeSeconds", "latitude",
            "longitude", "altitudeMeters", "horizontalAccuracyMeters",
            "verticalAccuracyMeters", "speedMetersPerSecond",
            "speedAccuracyMetersPerSecond", "courseDegreesTrue",
            "courseAccuracyDegrees",
        ],
    )
    calculations = calculation_rows(events)
    write_csv(
        output / "calculations.csv",
        calculations,
        list(calculations[0].keys()) if calculations else [
            "sequence", "timestamp", "tot", "distanceMeters", "bearingDegreesTrue",
            "trackDegreesTrue", "eteSeconds", "eta", "deltaSeconds",
            "requiredGroundSpeedMetersPerSecond", "status", "isFixStale",
            "turnDirection", "turnInDirection", "turnDurationSeconds",
        ],
    )

    report_text = make_report_text(report, warnings)
    (output / "report.txt").write_text(report_text, encoding="utf-8")
    print(report_text, end="")
    print(f"Decoded files: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
