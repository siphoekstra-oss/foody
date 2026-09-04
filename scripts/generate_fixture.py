#!/usr/bin/env python3
"""M0-nepdata: maakt availability.json (schema_version 1) uit crawler/restaurants.json.

De restaurants zijn echt, de tijdsloten zijn verzonnen. Het bestand krijgt "source": "fixture",
waardoor de app een testdata-badge toont. In M2 vervangt de crawler dit script.

Gebruik:  python3 scripts/generate_fixture.py [--out PAD] [--days 30] [--start YYYY-MM-DD]
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import random
import sys
from pathlib import Path
from zoneinfo import ZoneInfo

AMSTERDAM = ZoneInfo("Europe/Amsterdam")
SCHEMA_VERSION = 1
LUNCH_TIMES = ["12:00", "12:15", "12:30", "13:00", "13:30"]
DINNER_TIMES = ["17:30", "18:00", "18:30", "19:00", "19:30", "20:00", "20:30", "21:00"]
COVERS_POOL = [2, 2, 4, 4, 6]
FULLY_BOOKED_DINNER_CHANCE = 0.35   # hotspots zitten vaak vol
WEEKEND_FULLY_BOOKED_BONUS = 0.25
ROOT = Path(__file__).resolve().parent.parent
SOURCE_ONLY_FIELDS = ["serves_lunch"]
CONTRACT_FIELDS = [
    "id", "name", "cuisine", "guides", "price_indication_eur", "lat", "lon", "address",
    "phone", "website_url", "image_url", "booking_provider", "booking_url", "deeplink_template",
]


def service_for(time_hhmm: str) -> str:
    """Vóór 16:00 is lunch, daarna diner. Expliciet in de JSON, niet in de app."""
    hour = int(time_hhmm.split(":")[0])
    return "lunch" if hour < 16 else "dinner"


def slots_for(restaurant_id: str, day: dt.date, serves_lunch: bool) -> list[dict]:
    seed = int(hashlib.sha256(f"{restaurant_id}:{day.isoformat()}".encode()).hexdigest(), 16)
    rng = random.Random(seed)
    slots: list[dict] = []
    is_weekend = day.weekday() >= 4  # vr, za, zo zitten voller
    if serves_lunch and rng.random() < 0.6:
        for time in rng.sample(LUNCH_TIMES, rng.randint(1, 3)):
            slots.append({"time": time, "service": service_for(time), "max_covers": rng.choice(COVERS_POOL)})
    full_chance = FULLY_BOOKED_DINNER_CHANCE + (WEEKEND_FULLY_BOOKED_BONUS if is_weekend else 0)
    if rng.random() >= full_chance:
        for time in rng.sample(DINNER_TIMES, rng.randint(1, 2 if is_weekend else 4)):
            slots.append({"time": time, "service": service_for(time), "max_covers": rng.choice(COVERS_POOL)})
    return sorted(slots, key=lambda s: s["time"])


def build(source: dict, start: dt.date, days: int, generated_at: dt.datetime) -> dict:
    restaurants = []
    for r in source["restaurants"]:
        missing = [f for f in CONTRACT_FIELDS + SOURCE_ONLY_FIELDS if f not in r]
        if missing:
            sys.exit(f"restaurant {r.get('id')!r} mist velden: {missing}")
        has_online_booking = r["booking_provider"] != "none" and r["booking_url"]
        serves_lunch = bool(r["serves_lunch"])
        availability = []
        if has_online_booking:
            for offset in range(days):
                day = start + dt.timedelta(days=offset)
                slots = slots_for(r["id"], day, serves_lunch)
                if slots:
                    availability.append({"date": day.isoformat(), "slots": slots})
        out = {f: r[f] for f in CONTRACT_FIELDS}
        out["deeplink_template"] = r["deeplink_template"] or r["booking_url"]
        out["status"] = "live" if has_online_booking else "link_only"
        out["last_checked"] = iso_z(generated_at)
        out["availability"] = availability
        restaurants.append(out)
    return {
        "generated_at": iso_z(generated_at),
        "schema_version": SCHEMA_VERSION,
        "city": source["region"],
        "source": "fixture",
        "restaurants": restaurants,
    }


def iso_z(moment: dt.datetime) -> str:
    return moment.astimezone(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source", type=Path, default=ROOT / "crawler" / "restaurants.json")
    parser.add_argument("--out", type=Path, default=ROOT / "Foody" / "Resources" / "availability.json")
    parser.add_argument("--days", type=int, default=30)
    parser.add_argument("--start", type=dt.date.fromisoformat, default=dt.datetime.now(AMSTERDAM).date())
    args = parser.parse_args()

    source = json.loads(args.source.read_text(encoding="utf-8"))
    document = build(source, args.start, args.days, dt.datetime.now(dt.timezone.utc))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    live = sum(1 for r in document["restaurants"] if r["status"] == "live")
    slots = sum(len(d["slots"]) for r in document["restaurants"] for d in r["availability"])
    print(f"{args.out}: {len(document['restaurants'])} restaurants ({live} live), {slots} nepsloten over {args.days} dagen vanaf {args.start}")


if __name__ == "__main__":
    main()
