"""Leesverzoeken volgens de gedragsregels uit CLAUDE.md: herkenbare User-Agent met contactadres,
sequentieel met minimaal 2 seconden ertussen, robots.txt respecteren, bij 403/429 het restaurant
24 uur overslaan met exponentiële backoff voor tijdelijke fouten. Alleen lezen, nooit boeken."""
from __future__ import annotations

import json
import logging
import time
import urllib.error
import urllib.request
import urllib.robotparser
from pathlib import Path
from urllib.parse import urlsplit

USER_AGENT = "FoodyBot/0.1 (+foody@voorbeeld.nl)"
MIN_INTERVAL_SECONDS = 2.0
SKIP_SECONDS = 24 * 3600
TIMEOUT_SECONDS = 20
RETRY_DELAYS = (2, 4, 8)

log = logging.getLogger("foody.http")


class FetchError(Exception):
    """Het verzoek is niet gelukt; de adapter meldt status unknown."""


class RobotsDisallowed(FetchError):
    pass


class RateLimited(FetchError):
    pass


class Skipped(FetchError):
    pass


class Fetcher:
    def __init__(self, skip_path: Path, *, user_agent: str = USER_AGENT, min_interval: float = MIN_INTERVAL_SECONDS,
                 sleep=time.sleep, now=time.time, opener=None):
        self.user_agent = user_agent
        self.min_interval = min_interval
        self._sleep = sleep
        self._now = now
        self._opener = opener or urllib.request.build_opener()
        self._skip_path = skip_path
        self._skips: dict[str, float] = self._load_skips()
        self._robots: dict[str, urllib.robotparser.RobotFileParser | None] = {}
        self._last_request_at: float | None = None
        self.request_count = 0

    # -- publiek --------------------------------------------------------------------------------

    def get_json(self, url: str, *, headers: dict | None = None, restaurant_id: str) -> object:
        return self._request("GET", url, None, headers or {}, restaurant_id)

    def post_json(self, url: str, body: dict, *, headers: dict | None = None, restaurant_id: str) -> object:
        data = json.dumps(body).encode("utf-8")
        return self._request("POST", url, data, {"Content-Type": "application/json", **(headers or {})}, restaurant_id)

    def is_skipped(self, restaurant_id: str) -> bool:
        until = self._skips.get(restaurant_id)
        return until is not None and until > self._now()

    # -- intern ---------------------------------------------------------------------------------

    def _request(self, method: str, url: str, data: bytes | None, headers: dict, restaurant_id: str) -> object:
        if self.is_skipped(restaurant_id):
            raise Skipped(f"{restaurant_id} wordt 24 uur overgeslagen na een eerdere 403/429")
        if not self._robots_allow(url):
            raise RobotsDisallowed(f"robots.txt van {urlsplit(url).netloc} staat {url} niet toe")
        attempts = (0,) + RETRY_DELAYS
        for index, delay in enumerate(attempts):
            if delay:
                self._sleep(delay)
            try:
                raw = self._send(method, url, data, headers)
                return json.loads(raw)
            except urllib.error.HTTPError as error:
                if error.code in (403, 429):
                    self._skip(restaurant_id)
                    raise RateLimited(f"HTTP {error.code} voor {url}; {restaurant_id} 24 uur overgeslagen") from error
                if 500 <= error.code < 600 and index < len(attempts) - 1:
                    log.warning("HTTP %s voor %s, nieuwe poging over %ss", error.code, url, attempts[index + 1])
                    continue
                raise FetchError(f"HTTP {error.code} voor {url}") from error
            except (urllib.error.URLError, TimeoutError) as error:
                if index < len(attempts) - 1:
                    log.warning("netwerkfout voor %s (%s), nieuwe poging over %ss", url, error, attempts[index + 1])
                    continue
                raise FetchError(f"netwerkfout voor {url}: {error}") from error
            except json.JSONDecodeError as error:
                raise FetchError(f"geen geldige JSON van {url}") from error
        raise FetchError(f"geen antwoord van {url}")

    def _send(self, method: str, url: str, data: bytes | None, headers: dict) -> bytes:
        self._throttle()
        request = urllib.request.Request(url, data=data, method=method, headers={"User-Agent": self.user_agent, **headers})
        self.request_count += 1
        with self._opener.open(request, timeout=TIMEOUT_SECONDS) as response:
            return response.read()

    def _throttle(self) -> None:
        if self._last_request_at is not None:
            wait = self.min_interval - (self._now() - self._last_request_at)
            if wait > 0:
                self._sleep(wait)
        self._last_request_at = self._now()

    def _robots_allow(self, url: str) -> bool:
        host = urlsplit(url).netloc
        if host not in self._robots:
            self._robots[host] = self._load_robots(f"https://{host}/robots.txt")
        parser = self._robots[host]
        return True if parser is None else parser.can_fetch(self.user_agent, url)

    def _load_robots(self, robots_url: str) -> urllib.robotparser.RobotFileParser | None:
        try:
            raw = self._send("GET", robots_url, None, {})
        except urllib.error.HTTPError as error:
            if error.code >= 500:
                log.warning("robots.txt %s gaf HTTP %s; host wordt als toegestaan behandeld", robots_url, error.code)
            return None  # geen robots.txt (4xx) = geen beperkingen
        except (urllib.error.URLError, TimeoutError):
            log.warning("robots.txt %s onbereikbaar; host wordt als toegestaan behandeld", robots_url)
            return None
        parser = urllib.robotparser.RobotFileParser()
        parser.parse(raw.decode("utf-8", errors="replace").splitlines())
        return parser

    def _skip(self, restaurant_id: str) -> None:
        self._skips[restaurant_id] = self._now() + SKIP_SECONDS
        self._skip_path.parent.mkdir(parents=True, exist_ok=True)
        self._skip_path.write_text(json.dumps(self._skips, indent=2), encoding="utf-8")

    def _load_skips(self) -> dict[str, float]:
        try:
            data = json.loads(self._skip_path.read_text(encoding="utf-8"))
            return {k: float(v) for k, v in data.items()}
        except (FileNotFoundError, ValueError, AttributeError):
            return {}
