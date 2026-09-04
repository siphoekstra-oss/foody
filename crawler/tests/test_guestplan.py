import datetime as dt
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from adapters import guestplan  # noqa: E402
from contract import ContractError  # noqa: E402

START, END = dt.date(2026, 9, 4), dt.date(2026, 10, 3)
SERVICES = {"38296": "lunch", "38297": "dinner"}


class GuestplanParseTests(unittest.TestCase):
    def test_month_maps_available_days_to_services(self):
        data = {"drs": [
            {"d": "20260904", "o": True, "a": True, "avs": [38297]},
            {"d": "20260905", "o": True, "a": True, "avs": [38296, 38297]},
            {"d": "20260906", "o": True, "a": False, "avs": []},
            {"d": "20260903", "o": True, "a": True, "avs": [38296]},
        ]}
        days = guestplan.parse_month(data, START, END, SERVICES, "coco73")
        self.assertEqual(days, [
            {"date": "2026-09-04", "slots": [], "services_available": ["dinner"]},
            {"date": "2026-09-05", "slots": [], "services_available": ["lunch", "dinner"]},
        ])

    def test_unknown_service_ids_are_ignored_not_invented(self):
        data = {"drs": [{"d": 20260907, "a": True, "avs": [99999]}]}
        self.assertEqual(guestplan.parse_month(data, START, END, SERVICES, "x"), [])

    def test_day_slots_use_available_times_only(self):
        data = {"trs": [{"t": "11:15"}, {"t": "11:30", "o": True, "a": True, "avs": [38296]}, {"t": "17:00", "o": True, "a": True, "avs": [38297]}]}
        self.assertEqual(guestplan.parse_day_slots(data), [
            {"time": "11:30", "service": "lunch", "max_covers": 2},
            {"time": "17:00", "service": "dinner", "max_covers": 2}])

    def test_months_between_spans_month_boundary(self):
        self.assertEqual(guestplan.months_between(dt.date(2026, 9, 20), dt.date(2026, 10, 19)), [dt.date(2026, 9, 1), dt.date(2026, 10, 1)])

    def test_contract_change_raises(self):
        with self.assertRaises(ContractError):
            guestplan.parse_month({"days": []}, START, END, SERVICES, "x")
        with self.assertRaises(ContractError):
            guestplan.parse_day_slots({"times": []})


class FakeFetcher:
    def __init__(self, responses):
        self.responses, self.calls = responses, []

    def post_json(self, url, body, *, headers, restaurant_id):
        self.calls.append(body)
        return self.responses[body["date"]]


class GuestplanFetchTests(unittest.TestCase):
    restaurant = {"id": "coco73", "provider_venue_id": "key", "provider_account_id": 53496,
                  "provider_meta": {"services": SERVICES, "detail_days": 1}}

    def test_one_month_request_plus_detail_for_first_available_day(self):
        fetcher = FakeFetcher({
            "20260900": {"drs": [{"d": "20260905", "a": True, "avs": [38297]}, {"d": "20260906", "a": True, "avs": [38296]}]},
            "20260905": {"trs": [{"t": "17:00", "a": True, "avs": [38297]}]},
        })
        days = guestplan.fetch_availability(self.restaurant, dt.date(2026, 9, 4), dt.date(2026, 9, 30), fetcher, None)
        self.assertEqual([c["date"] for c in fetcher.calls], ["20260900", "20260905"])
        self.assertEqual(days[0]["slots"], [{"time": "17:00", "service": "dinner", "max_covers": 2}])
        self.assertEqual(days[0]["services_available"], ["dinner"])
        self.assertEqual(days[1]["slots"], [])

    def test_missing_meta_is_a_contract_error(self):
        with self.assertRaises(ContractError):
            guestplan.fetch_availability({"id": "x", "provider_venue_id": "k"}, START, END, FakeFetcher({}), None)


if __name__ == "__main__":
    unittest.main()
