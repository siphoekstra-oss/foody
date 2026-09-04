#!/usr/bin/env python3
"""Loopt alle restaurants uit crawler/restaurants.json af, roept per booking_provider de adapter aan
en schrijft availability.json (schema_version 1). Faalt een adapter, dan krijgt dat restaurant
status "unknown" en eindigt dit script met exit-code 2, zodat een cron zichtbaar rood wordt terwijl
het eerlijke bestand tóch wordt weggeschreven. Nooit oude data als vers presenteren.

Gebruik: python3 crawler/build.py [--out PAD] [--days 30] [--source crawler/restaurants.json]
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import logging
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import contract  # noqa: E402
from adapters import ADAPTERS  # noqa: E402
from http_client import FetchError, Fetcher  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
log = logging.getLogger("foody.build")


def crawl(source: dict, fetcher: Fetcher, start: dt.date, days: int, now: dt.datetime) -> tuple[dict, bool]:
    end = start + dt.timedelta(days=days - 1)
    restaurants, all_ok = [], True
    for r in source["restaurants"]:
        adapter = ADAPTERS.get(r.get("booking_provider"))
        if adapter is None or not r.get("booking_url"):
            restaurants.append(contract.restaurant_entry(r, "link_only", [], None))
            log.info("%-14s link_only (provider %s)", r["id"], r.get("booking_provider"))
            continue
        checked_at = dt.datetime.now(dt.timezone.utc)
        try:
            availability = adapter(r, start, end, fetcher, now)
            restaurants.append(contract.restaurant_entry(r, "live", availability, checked_at))
            slots = sum(len(d["slots"]) for d in availability)
            log.info("%-14s live: %d dagen, %d tijdsloten", r["id"], len(availability), slots)
        except (FetchError, contract.ContractError) as error:
            all_ok = False
            restaurants.append(contract.restaurant_entry(r, "unknown", [], checked_at))
            log.error("%-14s unknown: %s", r["id"], error)
    return contract.document(source["region"], restaurants, dt.datetime.now(dt.timezone.utc)), all_ok


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source", type=Path, default=ROOT / "crawler" / "restaurants.json")
    parser.add_argument("--out", type=Path, default=ROOT / "Foody" / "Resources" / "availability.json")
    parser.add_argument("--days", type=int, default=30)
    parser.add_argument("--cache-dir", type=Path, default=ROOT / "crawler" / ".cache")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s: %(message)s")

    source = json.loads(args.source.read_text(encoding="utf-8"))
    now = dt.datetime.now(contract.AMSTERDAM)
    fetcher = Fetcher(args.cache_dir / "skip.json")
    doc, all_ok = crawl(source, fetcher, now.date(), args.days, now)

    errors = contract.validate_document(doc)
    if errors:
        for e in errors:
            log.error("contract: %s", e)
        return 1
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    log.info("%s geschreven; %d verzoeken gedaan", args.out, fetcher.request_count)
    return 0 if all_ok else 2


if __name__ == "__main__":
    sys.exit(main())
