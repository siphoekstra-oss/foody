"""Zenchef (voorheen Formitable). Eén leesverzoek per restaurant per run levert alle shifts en
tijdsloten voor het gevraagde bereik, met per slot de mogelijke gezelschapsgroottes.

Endpoint zoals de publieke boekingspagina bookings.zenchef.com het zelf aanroept:
GET https://bookings-middleware.zenchef.com/getAvailabilities?restaurantId=<rid>&date_begin=<d>&date_end=<d>
Antwoord: [{"date": "YYYY-MM-DD", "shifts": [{"name", "closed", "marked_as_full",
           "shift_slots": [{"name": "HH:mm", "possible_guests": [..], "closed", "marked_as_full", "bookable_to"}]}]}]
"""
from __future__ import annotations

import datetime as dt

from contract import AMSTERDAM, ContractError, require, sorted_slots

BASE_URL = "https://bookings-middleware.zenchef.com"


def fetch_availability(restaurant: dict, start: dt.date, end: dt.date, fetcher, now: dt.datetime) -> list[dict]:
    rid = restaurant["provider_venue_id"]
    url = f"{BASE_URL}/getAvailabilities?restaurantId={rid}&date_begin={start.isoformat()}&date_end={end.isoformat()}"
    data = fetcher.get_json(url, headers={"Accept": "application/json"}, restaurant_id=restaurant["id"])
    return parse_days(data, start, end, now)


def parse_days(data: object, start: dt.date, end: dt.date, now: dt.datetime) -> list[dict]:
    if not isinstance(data, list):
        raise ContractError(f"zenchef: verwacht een lijst van dagen, kreeg {type(data).__name__}")
    days = []
    for day in data:
        require(day, "date", "shifts")
        date = _parse_date(day["date"])
        if date is None or date < start or date > end:
            continue  # de API geeft hele maanden terug, soms met onbestaande data zoals 09-31
        slots: dict[str, int] = {}
        for shift in day["shifts"]:
            require(shift, "shift_slots")
            if shift.get("closed") or shift.get("marked_as_full"):
                continue
            for entry in shift["shift_slots"]:
                require(entry, "name", "possible_guests")
                guests = entry["possible_guests"]
                if entry.get("closed") or entry.get("marked_as_full") or not guests:
                    continue
                if not _still_bookable(entry.get("bookable_to"), now):
                    continue
                covers = max(int(g) for g in guests)
                slots[entry["name"]] = max(slots.get(entry["name"], 0), covers)
        if slots:
            days.append({"date": date.isoformat(), "slots": sorted_slots(slots)})
    return days


def _parse_date(text: object) -> dt.date | None:
    try:
        return dt.date.fromisoformat(str(text))
    except ValueError:
        return None


def _still_bookable(bookable_to: object, now: dt.datetime) -> bool:
    """`bookable_to` is lokale tijd Amsterdam, bijv. "2026-09-05 16:00:00"; ontbreekt het, dan tellen we het slot mee."""
    if not isinstance(bookable_to, str):
        return True
    try:
        deadline = dt.datetime.strptime(bookable_to, "%Y-%m-%d %H:%M:%S").replace(tzinfo=AMSTERDAM)
    except ValueError:
        return True
    return deadline > now
