"""Registry: booking_provider -> fetch_availability(restaurant, start, end, fetcher, now) -> list[dag].
Een provider die hier niet in staat, levert status link_only op."""
from __future__ import annotations

from . import guestplan, zenchef

ADAPTERS = {
    "zenchef": zenchef.fetch_availability,
    "guestplan": guestplan.fetch_availability,
}
