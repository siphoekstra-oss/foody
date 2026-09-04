import io
import json
import sys
import tempfile
import unittest
import urllib.error
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from http_client import Fetcher, RateLimited, RobotsDisallowed, Skipped  # noqa: E402


class FakeResponse(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()


class FakeOpener:
    """Speelt de server: een lijst van (statuscode, body) per URL, in volgorde."""

    def __init__(self, script):
        self.script, self.requests = script, []

    def open(self, request, timeout):
        self.requests.append(request)
        code, body = self.script[request.full_url].pop(0)
        if code != 200:
            raise urllib.error.HTTPError(request.full_url, code, "fout", {}, None)
        return FakeResponse(body.encode())


class FakeClock:
    def __init__(self):
        self.t, self.sleeps = 1000.0, []

    def now(self):
        return self.t

    def sleep(self, seconds):
        self.sleeps.append(seconds)
        self.t += seconds


def make_fetcher(script, clock):
    tmp = Path(tempfile.mkdtemp()) / "skip.json"
    return Fetcher(tmp, sleep=clock.sleep, now=clock.now, opener=FakeOpener(script)), tmp


class FetcherTests(unittest.TestCase):
    def test_keeps_two_seconds_between_requests_including_robots(self):
        clock = FakeClock()
        fetcher, _ = make_fetcher({"https://api.test/robots.txt": [(404, "")],
                                   "https://api.test/a": [(200, "[1]")], "https://api.test/b": [(200, "[2]")]}, clock)
        fetcher.get_json("https://api.test/a", restaurant_id="r")
        fetcher.get_json("https://api.test/b", restaurant_id="r")
        self.assertEqual(clock.sleeps, [2.0, 2.0])
        self.assertEqual(fetcher.request_count, 3)

    def test_robots_disallow_blocks_without_requesting(self):
        clock = FakeClock()
        fetcher, _ = make_fetcher({"https://widget.test/robots.txt": [(200, "User-agent: *\nDisallow: /\n")]}, clock)
        with self.assertRaises(RobotsDisallowed):
            fetcher.get_json("https://widget.test/x", restaurant_id="r")
        self.assertEqual(fetcher.request_count, 1)

    def test_429_skips_restaurant_for_24_hours_and_persists(self):
        clock = FakeClock()
        fetcher, skip_path = make_fetcher({"https://api.test/robots.txt": [(404, "")], "https://api.test/a": [(429, "")]}, clock)
        with self.assertRaises(RateLimited):
            fetcher.get_json("https://api.test/a", restaurant_id="r")
        with self.assertRaises(Skipped):
            fetcher.get_json("https://api.test/a", restaurant_id="r")
        self.assertAlmostEqual(json.loads(skip_path.read_text())["r"], clock.now() + 24 * 3600, delta=10)
        clock.t += 24 * 3600 + 1
        self.assertFalse(fetcher.is_skipped("r"))

    def test_server_error_retries_with_backoff_then_succeeds(self):
        clock = FakeClock()
        fetcher, _ = make_fetcher({"https://api.test/robots.txt": [(404, "")], "https://api.test/a": [(503, ""), (503, ""), (200, "{\"ok\": true}")]}, clock)
        self.assertEqual(fetcher.get_json("https://api.test/a", restaurant_id="r"), {"ok": True})
        self.assertIn(2, clock.sleeps)
        self.assertIn(4, clock.sleeps)

    def test_user_agent_identifies_the_bot(self):
        clock = FakeClock()
        fetcher, _ = make_fetcher({"https://api.test/robots.txt": [(404, "")], "https://api.test/a": [(200, "1")]}, clock)
        fetcher.get_json("https://api.test/a", restaurant_id="r")
        self.assertIn("FoodyBot", fetcher._opener.requests[-1].get_header("User-agent"))


if __name__ == "__main__":
    unittest.main()
