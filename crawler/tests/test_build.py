import datetime as dt
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import build  # noqa: E402
import contract  # noqa: E402
from http_client import FetchError  # noqa: E402

BASE = {"name": "X", "cuisine": "Bistro", "guides": {"michelin_stars": None, "gaultmillau": None, "bib": None},
        "price_indication_eur": None, "lat": 51.68, "lon": 5.30, "address": "Straat 1", "phone": None,
        "website_url": None, "image_url": None, "deeplink_template": None}


def restaurant(rid, provider, booking_url="https://b.test/"):
    return {**BASE, "id": rid, "booking_provider": provider, "booking_url": booking_url, "provider_venue_id": "1"}


class BuildTests(unittest.TestCase):
    def setUp(self):
        self.now = dt.datetime(2026, 9, 4, 12, 0, tzinfo=contract.AMSTERDAM)
        self.saved = dict(build.ADAPTERS)

    def tearDown(self):
        build.ADAPTERS.clear()
        build.ADAPTERS.update(self.saved)

    def test_unknown_provider_becomes_link_only_and_adapter_failure_becomes_unknown(self):
        def failing(r, start, end, fetcher, now):
            raise FetchError("kaput")
        build.ADAPTERS.clear()
        build.ADAPTERS["failing"] = failing
        source = {"region": "den-bosch", "restaurants": [restaurant("a", "none", None), restaurant("b", "failing")]}
        doc, ok = build.crawl(source, fetcher=None, start=self.now.date(), days=3, now=self.now)
        self.assertFalse(ok)
        self.assertEqual([r["status"] for r in doc["restaurants"]], ["link_only", "unknown"])
        self.assertEqual(contract.validate_document(doc), [])
        self.assertEqual(doc["source"], "crawler")

    def test_live_result_is_written_with_last_checked(self):
        build.ADAPTERS.clear()
        build.ADAPTERS["ok"] = lambda r, s, e, f, n: [{"date": "2026-09-05", "slots": [contract.slot("19:00", 4)]}]
        doc, ok = build.crawl({"region": "den-bosch", "restaurants": [restaurant("a", "ok")]}, None, self.now.date(), 3, self.now)
        self.assertTrue(ok)
        r = doc["restaurants"][0]
        self.assertEqual(r["status"], "live")
        self.assertTrue(r["last_checked"].endswith("Z"))
        self.assertEqual(r["deeplink_template"], "https://b.test/")

    def test_validate_document_catches_bad_slots(self):
        doc = contract.document("den-bosch", [contract.restaurant_entry(restaurant("a", "ok"), "live",
                                [{"date": "2026-09-05", "slots": [{"time": "19:00", "service": "lunch", "max_covers": 2}]}], None)],
                                dt.datetime.now(dt.timezone.utc))
        self.assertTrue(any("ongeldig slot" in e for e in contract.validate_document(doc)))


if __name__ == "__main__":
    unittest.main()
