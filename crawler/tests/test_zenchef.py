import datetime as dt
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from adapters import zenchef  # noqa: E402
from contract import AMSTERDAM, ContractError  # noqa: E402

NOW = dt.datetime(2026, 9, 4, 12, 0, tzinfo=AMSTERDAM)
START, END = dt.date(2026, 9, 4), dt.date(2026, 9, 10)


def slot(name, guests, **extra):
    return {"name": name, "possible_guests": guests, "closed": False, "marked_as_full": False,
            "bookable_to": "2026-09-05 21:00:00", **extra}


def day(date, *shifts):
    return {"date": date, "shifts": list(shifts)}


def shift(name, slots, **extra):
    return {"name": name, "closed": False, "marked_as_full": False, "shift_slots": slots, **extra}


class ZenchefParseTests(unittest.TestCase):
    def test_keeps_bookable_slots_with_max_covers_and_service_by_time(self):
        data = [day("2026-09-05", shift("Lunch", [slot("12:15", [1, 2, 3, 4])]), shift("Diner", [slot("19:30", [2, 1])]))]
        days = zenchef.parse_days(data, START, END, NOW)
        self.assertEqual(days, [{"date": "2026-09-05", "slots": [
            {"time": "12:15", "service": "lunch", "max_covers": 4},
            {"time": "19:30", "service": "dinner", "max_covers": 2}]}])

    def test_skips_full_closed_and_empty_slots_and_drops_empty_days(self):
        data = [day("2026-09-05", shift("Diner", [slot("18:00", []), slot("18:30", [2], closed=True), slot("19:00", [2], marked_as_full=True)]))]
        self.assertEqual(zenchef.parse_days(data, START, END, NOW), [])

    def test_skips_closed_shift_and_past_bookable_to(self):
        data = [day("2026-09-05", shift("Diner", [slot("19:00", [2])], closed=True)),
                day("2026-09-06", shift("Lunch", [slot("12:00", [2], bookable_to="2026-09-04 11:00:00")]))]
        self.assertEqual(zenchef.parse_days(data, START, END, NOW), [])

    def test_ignores_days_outside_range_and_invalid_dates(self):
        data = [day("2026-09-01", shift("Diner", [slot("19:00", [2])])),
                day("2026-09-31", shift("Diner", [slot("19:00", [2])])),
                day("2026-09-11", shift("Diner", [slot("19:00", [2])]))]
        self.assertEqual(zenchef.parse_days(data, START, END, NOW), [])

    def test_same_time_in_two_shifts_keeps_largest_party(self):
        data = [day("2026-09-05", shift("A", [slot("17:00", [2])]), shift("B", [slot("17:00", [4, 6])]))]
        self.assertEqual(zenchef.parse_days(data, START, END, NOW)[0]["slots"][0]["max_covers"], 6)

    def test_contract_change_raises(self):
        with self.assertRaises(ContractError):
            zenchef.parse_days({"days": []}, START, END, NOW)
        with self.assertRaises(ContractError):
            zenchef.parse_days([{"date": "2026-09-05", "shifts": [{"name": "Diner", "slots": []}]}], START, END, NOW)


if __name__ == "__main__":
    unittest.main()
