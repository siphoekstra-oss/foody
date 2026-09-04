"""Het datacontract (schema_version 1) zoals de app het leest, plus de controles die een adapter
laten falen zodra het antwoordformaat van een boekingssysteem verandert."""
from __future__ import annotations

import datetime as dt
import re
from zoneinfo import ZoneInfo

SCHEMA_VERSION = 1
AMSTERDAM = ZoneInfo("Europe/Amsterdam")
LUNCH_BEFORE_HOUR = 16
SERVICE_ORDER = {"lunch": 0, "dinner": 1}
TIME_PATTERN = re.compile(r"^([01]\d|2[0-3]):[0-5]\d$")

# Velden die één-op-één van crawler/restaurants.json naar availability.json gaan.
RESTAURANT_FIELDS = [
    "id", "name", "cuisine", "guides", "price_indication_eur", "lat", "lon", "address",
    "phone", "website_url", "image_url", "booking_provider", "booking_url", "deeplink_template",
]


class ContractError(Exception):
    """Het antwoord van een boekingssysteem heeft niet de verwachte vorm."""


def require(obj: object, *keys: str) -> None:
    if not isinstance(obj, dict):
        raise ContractError(f"verwacht een object met {keys}, kreeg {type(obj).__name__}")
    missing = [k for k in keys if k not in obj]
    if missing:
        raise ContractError(f"ontbrekende velden {missing} in {sorted(obj)[:12]}")


def service_for(time_hhmm: str) -> str:
    """Vóór 16:00 is lunch, daarna diner. Expliciet in de JSON; de app leidt niets af."""
    return "lunch" if int(time_hhmm[:2]) < LUNCH_BEFORE_HOUR else "dinner"


def valid_time(time_hhmm: object) -> bool:
    return isinstance(time_hhmm, str) and TIME_PATTERN.match(time_hhmm) is not None


def slot(time_hhmm: str, max_covers: int) -> dict:
    if not valid_time(time_hhmm):
        raise ContractError(f"ongeldige tijd {time_hhmm!r}")
    return {"time": time_hhmm, "service": service_for(time_hhmm), "max_covers": int(max_covers)}


def sorted_slots(slots: dict[str, int]) -> list[dict]:
    return [slot(t, c) for t, c in sorted(slots.items())]


def iso_z(moment: dt.datetime) -> str:
    return moment.astimezone(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def restaurant_entry(source: dict, status: str, days: list[dict], last_checked: dt.datetime | None) -> dict:
    missing = [f for f in RESTAURANT_FIELDS if f not in source]
    if missing:
        raise ContractError(f"restaurants.json: {source.get('id')!r} mist {missing}")
    entry = {field: source[field] for field in RESTAURANT_FIELDS}
    entry["deeplink_template"] = source["deeplink_template"] or source["booking_url"]
    entry["status"] = status
    entry["last_checked"] = iso_z(last_checked) if last_checked else None
    entry["availability"] = days
    return entry


def document(city: str, restaurants: list[dict], generated_at: dt.datetime) -> dict:
    return {
        "generated_at": iso_z(generated_at),
        "schema_version": SCHEMA_VERSION,
        "city": city,
        "source": "crawler",
        "restaurants": restaurants,
    }


def validate_document(doc: dict) -> list[str]:
    """Controleert het uitgeschreven bestand tegen het contract. Lege lijst = geldig."""
    errors: list[str] = []
    if doc.get("schema_version") != SCHEMA_VERSION:
        errors.append("schema_version klopt niet")
    ids = [r.get("id") for r in doc.get("restaurants", [])]
    if len(ids) != len(set(ids)):
        errors.append("dubbele restaurant-id's")
    for r in doc.get("restaurants", []):
        prefix = f"{r.get('id')}: "
        if r.get("status") not in ("live", "link_only", "unknown"):
            errors.append(prefix + f"ongeldige status {r.get('status')!r}")
        if r.get("status") == "live" and not r.get("booking_url"):
            errors.append(prefix + "live zonder booking_url")
        if not (50.5 <= float(r.get("lat", 0)) <= 53.7 and 3.2 <= float(r.get("lon", 0)) <= 7.3):
            errors.append(prefix + "coördinaten buiten Nederland")
        for day in r.get("availability", []):
            try:
                dt.date.fromisoformat(day.get("date", ""))
            except ValueError:
                errors.append(prefix + f"ongeldige datum {day.get('date')!r}")
            for s in day.get("slots", []):
                if not valid_time(s.get("time")) or s.get("service") != service_for(s["time"]) or int(s.get("max_covers", 0)) < 1:
                    errors.append(prefix + f"ongeldig slot {s!r}")
            for svc in day.get("services_available", []):
                if svc not in SERVICE_ORDER:
                    errors.append(prefix + f"ongeldig dagdeel {svc!r}")
    return errors
