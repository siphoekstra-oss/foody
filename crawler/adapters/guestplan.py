"""Guestplan. Het widget-API geeft per maand alleen per dag of er plek is en voor welke diensten,
en per dag alleen tijden voor één gezelschapsgrootte. Standaard doen we daarom één maandverzoek per
maand in het bereik (dag-niveau, 'services_available'); met provider_meta.detail_days > 0 komen er
voor de eerste N beschikbare dagen tijdsloten bij (één extra verzoek per dag, gezelschap van 2).

Endpoint zoals de widget het zelf aanroept, met de publieke access key van de restaurantsite:
POST https://api.guestplan.com/api/v2/getAvailability  Authorization: AccessKey <key>
  body {"accountId": <id>, "date": "YYYYMM00", "partySize": 2}   -> {"drs": [{"d": "YYYYMMDD", "a": bool, "avs": [dienst-id]}]}
  body {"accountId": <id>, "date": "YYYYMMDD", "partySize": 2}   -> {"trs": [{"t": "HH:mm", "a": bool, "avs": [dienst-id]}]}
De dienst-id's zijn per restaurant en staan in restaurants.json onder provider_meta.services.
"""
from __future__ import annotations

import datetime as dt
import logging

from contract import SERVICE_ORDER, ContractError, require, sorted_slots

API_URL = "https://api.guestplan.com/api/v2/getAvailability"
PARTY_SIZE = 2  # de maandvlaggen zijn onafhankelijk van gezelschapsgrootte (gecontroleerd met 2 en 6)

log = logging.getLogger("foody.guestplan")


def fetch_availability(restaurant: dict, start: dt.date, end: dt.date, fetcher, now: dt.datetime) -> list[dict]:
    meta = restaurant.get("provider_meta") or {}
    services = {str(k): v for k, v in (meta.get("services") or {}).items()}
    if not services or "provider_account_id" not in restaurant:
        raise ContractError(f"guestplan: {restaurant['id']} mist provider_account_id of provider_meta.services")
    headers = {"Authorization": f"AccessKey {restaurant['provider_venue_id']}", "Accept": "application/json"}
    account = restaurant["provider_account_id"]

    days: dict[str, dict] = {}
    for month in months_between(start, end):
        body = {"accountId": account, "date": month.strftime("%Y%m00"), "partySize": PARTY_SIZE}
        data = fetcher.post_json(API_URL, body, headers=headers, restaurant_id=restaurant["id"])
        for day in parse_month(data, start, end, services, restaurant["id"]):
            days[day["date"]] = day

    for date_iso in sorted(days)[: int(meta.get("detail_days") or 0)]:
        body = {"accountId": account, "date": date_iso.replace("-", ""), "partySize": PARTY_SIZE}
        data = fetcher.post_json(API_URL, body, headers=headers, restaurant_id=restaurant["id"])
        days[date_iso]["slots"] = parse_day_slots(data)
    return [days[k] for k in sorted(days)]


def months_between(start: dt.date, end: dt.date) -> list[dt.date]:
    months, cursor = [], start.replace(day=1)
    while cursor <= end:
        months.append(cursor)
        cursor = (cursor.replace(day=28) + dt.timedelta(days=4)).replace(day=1)
    return months


def parse_month(data: object, start: dt.date, end: dt.date, services: dict[str, str], restaurant_id: str) -> list[dict]:
    require(data, "drs")
    if not isinstance(data["drs"], list):
        raise ContractError("guestplan: 'drs' is geen lijst")
    days, unknown_ids = [], set()
    for entry in data["drs"]:
        require(entry, "d")
        date = _parse_yyyymmdd(entry["d"])
        if date is None or date < start or date > end or not entry.get("a"):
            continue
        ids = [str(i) for i in entry.get("avs") or []]
        unknown_ids.update(i for i in ids if i not in services)
        available = sorted({services[i] for i in ids if i in services}, key=SERVICE_ORDER.__getitem__)
        if available:
            days.append({"date": date.isoformat(), "slots": [], "services_available": available})
    if unknown_ids:
        log.warning("guestplan %s: onbekende dienst-id's %s; vul provider_meta.services aan", restaurant_id, sorted(unknown_ids))
    return days


def parse_day_slots(data: object) -> list[dict]:
    require(data, "trs")
    slots = {entry["t"]: PARTY_SIZE for entry in data["trs"] if isinstance(entry, dict) and entry.get("a") and "t" in entry}
    return sorted_slots(slots)


def _parse_yyyymmdd(value: object) -> dt.date | None:
    try:
        return dt.datetime.strptime(str(value), "%Y%m%d").date()
    except ValueError:
        return None
